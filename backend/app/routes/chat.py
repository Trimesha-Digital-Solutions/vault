from datetime import datetime
from typing import List, Optional

from bson import ObjectId
from fastapi import APIRouter, Depends, HTTPException, Query, status

from ..database import Database
from ..models import ChatMessage, ChatMessageCreate, ChatReadRequest, User
from ..websocket_manager import socket_manager
from .auth import get_current_user

router = APIRouter(prefix="/teams", tags=["chat"])


async def _get_team_with_membership(team_id: str, user_id: str) -> dict:
    if not ObjectId.is_valid(team_id):
        raise HTTPException(status_code=400, detail="Invalid team ID")

    team = await Database.db.teams.find_one(
        {"_id": ObjectId(team_id), "members.user_id": user_id}
    )
    if not team:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Team not found or access denied",
        )
    return team


@router.get("/{team_id}/messages", response_model=List[ChatMessage])
async def get_messages(
    team_id: str,
    limit: int = Query(default=50, ge=1, le=100),
    before: Optional[str] = Query(default=None),
    current_user: User = Depends(get_current_user),
):
    await _get_team_with_membership(team_id, current_user.id)

    query: dict = {"team_id": team_id}
    if before:
        if not ObjectId.is_valid(before):
            raise HTTPException(status_code=400, detail="Invalid message cursor")
        query["_id"] = {"$lt": ObjectId(before)}

    cursor = Database.db.chat_messages.find(query).sort("created_at", -1).limit(limit)
    docs = await cursor.to_list(length=limit)
    docs.reverse()

    return [
        ChatMessage(
            id=str(doc["_id"]),
            team_id=doc["team_id"],
            sender_id=doc["sender_id"],
            sender_name=doc["sender_name"],
            content=doc["content"],
            message_type=doc.get("message_type", "text"),
            reply_to_id=doc.get("reply_to_id"),
            reply_to_preview=doc.get("reply_to_preview"),
            reply_to_sender=doc.get("reply_to_sender"),
            is_deleted=doc.get("is_deleted", False),
            read_by=doc.get("read_by", []),
            created_at=doc["created_at"],
        )
        for doc in docs
    ]


@router.post("/{team_id}/messages", response_model=ChatMessage)
async def send_message(
    team_id: str,
    message_in: ChatMessageCreate,
    current_user: User = Depends(get_current_user),
):
    if not message_in.content.strip():
        raise HTTPException(status_code=400, detail="Message content cannot be empty")

    await _get_team_with_membership(team_id, current_user.id)

    reply_to_preview = None
    reply_to_sender = None
    if message_in.reply_to_id:
        if not ObjectId.is_valid(message_in.reply_to_id):
            raise HTTPException(status_code=400, detail="Invalid reply_to_id")
        reply_doc = await Database.db.chat_messages.find_one(
            {"_id": ObjectId(message_in.reply_to_id), "team_id": team_id}
        )
        if reply_doc:
            reply_to_preview = reply_doc.get("content", "")[:120]
            reply_to_sender = reply_doc.get("sender_name")

    sender_name = f"{current_user.first_name or ''} {current_user.last_name or ''}".strip()
    if not sender_name:
        sender_name = current_user.username

    payload = {
        "team_id": team_id,
        "sender_id": current_user.id,
        "sender_name": sender_name,
        "content": message_in.content.strip(),
        "message_type": message_in.message_type,
        "reply_to_id": message_in.reply_to_id,
        "reply_to_preview": reply_to_preview,
        "reply_to_sender": reply_to_sender,
        "is_deleted": False,
        "read_by": [current_user.id],
        "created_at": datetime.utcnow(),
    }
    result = await Database.db.chat_messages.insert_one(payload)

    response = ChatMessage(
        id=str(result.inserted_id),
        team_id=team_id,
        sender_id=payload["sender_id"],
        sender_name=payload["sender_name"],
        content=payload["content"],
        message_type=payload["message_type"],
        reply_to_id=payload["reply_to_id"],
        reply_to_preview=payload["reply_to_preview"],
        reply_to_sender=payload["reply_to_sender"],
        is_deleted=False,
        read_by=payload["read_by"],
        created_at=payload["created_at"],
    )
    # Socket.IO JSON-encodes the payload; use mode='json' so datetimes become strings.
    await socket_manager.emit_to_team(
        team_id, "message_new", response.model_dump(mode="json")
    )
    return response


@router.post("/{team_id}/messages/read", response_model=dict)
async def mark_message_read(
    team_id: str,
    read_in: ChatReadRequest,
    current_user: User = Depends(get_current_user),
):
    await _get_team_with_membership(team_id, current_user.id)
    if not ObjectId.is_valid(read_in.message_id):
        raise HTTPException(status_code=400, detail="Invalid message ID")

    result = await Database.db.chat_messages.update_one(
        {"_id": ObjectId(read_in.message_id), "team_id": team_id},
        {"$addToSet": {"read_by": current_user.id}},
    )
    if result.matched_count == 0:
        raise HTTPException(status_code=404, detail="Message not found")

    event_payload = {"message_id": read_in.message_id, "user_id": current_user.id}
    await socket_manager.emit_to_team(team_id, "message_read", event_payload)
    return {"success": True, "message": "Read receipt updated"}
