from datetime import datetime
from pathlib import Path
from uuid import uuid4
from typing import List

from bson import ObjectId
from fastapi import APIRouter, Depends, File, Form, HTTPException, UploadFile, status
from fastapi.responses import FileResponse

from ..database import Database
from ..models import Document, DocumentUpdateAccess, User
from .auth import get_current_user

router = APIRouter(prefix="/teams", tags=["documents"])
UPLOAD_ROOT = Path("uploads") / "documents"


def _can_view_document(doc: dict, user_id: str) -> bool:
    allowed = doc.get("allowed_member_ids", [])
    return not allowed or user_id in allowed


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


def _is_organiser(team: dict, user_id: str) -> bool:
    return any(m["user_id"] == user_id and m["role"] == "Organiser" for m in team["members"])


@router.post("/{team_id}/documents", response_model=Document)
async def upload_document(
    team_id: str,
    file: UploadFile = File(...),
    name: str = Form(...),
    allowed_member_ids: str = Form(default=""),
    current_user: User = Depends(get_current_user),
):
    team = await _get_team_with_membership(team_id, current_user.id)

    parsed_member_ids = [mid.strip() for mid in allowed_member_ids.split(",") if mid.strip()]
    valid_member_ids = {member["user_id"] for member in team["members"]}
    if any(mid not in valid_member_ids for mid in parsed_member_ids):
        raise HTTPException(status_code=400, detail="allowed_member_ids contains invalid team users")

    ext = Path(file.filename or "").suffix
    file_name = f"{uuid4().hex}{ext}"
    team_dir = UPLOAD_ROOT / team_id
    team_dir.mkdir(parents=True, exist_ok=True)
    server_path = team_dir / file_name

    content = await file.read()
    server_path.write_bytes(content)

    uploader_name = f"{current_user.first_name or ''} {current_user.last_name or ''}".strip()
    if not uploader_name:
        uploader_name = current_user.username

    doc = {
        "team_id": team_id,
        "name": name,
        "original_filename": file.filename or file_name,
        "file_path": str(server_path),
        "file_size": len(content),
        "mime_type": file.content_type or "application/octet-stream",
        "uploaded_by": current_user.id,
        "uploaded_by_name": uploader_name,
        "allowed_member_ids": parsed_member_ids,
        "created_at": datetime.utcnow(),
    }

    result = await Database.db.documents.insert_one(doc)
    return Document(
        id=str(result.inserted_id),
        team_id=team_id,
        name=doc["name"],
        original_filename=doc["original_filename"],
        file_size=doc["file_size"],
        mime_type=doc["mime_type"],
        uploaded_by=doc["uploaded_by"],
        uploaded_by_name=doc["uploaded_by_name"],
        allowed_member_ids=doc["allowed_member_ids"],
        created_at=doc["created_at"],
    )


@router.get("/{team_id}/documents", response_model=List[Document])
async def list_documents(
    team_id: str,
    current_user: User = Depends(get_current_user),
):
    await _get_team_with_membership(team_id, current_user.id)
    docs = await Database.db.documents.find({"team_id": team_id}).sort("created_at", -1).to_list(length=200)

    visible_docs = [doc for doc in docs if _can_view_document(doc, current_user.id)]
    return [
        Document(
            id=str(doc["_id"]),
            team_id=doc["team_id"],
            name=doc["name"],
            original_filename=doc["original_filename"],
            file_size=doc["file_size"],
            mime_type=doc["mime_type"],
            uploaded_by=doc["uploaded_by"],
            uploaded_by_name=doc["uploaded_by_name"],
            allowed_member_ids=doc.get("allowed_member_ids", []),
            created_at=doc["created_at"],
        )
        for doc in visible_docs
    ]


@router.get("/{team_id}/documents/{doc_id}/download")
async def download_document(
    team_id: str,
    doc_id: str,
    current_user: User = Depends(get_current_user),
):
    await _get_team_with_membership(team_id, current_user.id)
    if not ObjectId.is_valid(doc_id):
        raise HTTPException(status_code=400, detail="Invalid document ID")

    doc = await Database.db.documents.find_one({"_id": ObjectId(doc_id), "team_id": team_id})
    if not doc:
        raise HTTPException(status_code=404, detail="Document not found")
    if not _can_view_document(doc, current_user.id):
        raise HTTPException(status_code=403, detail="Access denied")

    file_path = Path(doc["file_path"])
    if not file_path.exists():
        raise HTTPException(status_code=404, detail="Document file missing")

    return FileResponse(
        path=file_path,
        filename=doc["original_filename"],
        media_type=doc.get("mime_type", "application/octet-stream"),
    )


@router.put("/{team_id}/documents/{doc_id}/access", response_model=Document)
async def update_document_access(
    team_id: str,
    doc_id: str,
    access_in: DocumentUpdateAccess,
    current_user: User = Depends(get_current_user),
):
    team = await _get_team_with_membership(team_id, current_user.id)
    if not ObjectId.is_valid(doc_id):
        raise HTTPException(status_code=400, detail="Invalid document ID")

    doc = await Database.db.documents.find_one({"_id": ObjectId(doc_id), "team_id": team_id})
    if not doc:
        raise HTTPException(status_code=404, detail="Document not found")

    if doc["uploaded_by"] != current_user.id and not _is_organiser(team, current_user.id):
        raise HTTPException(status_code=403, detail="Only uploader or organiser can update access")

    valid_member_ids = {member["user_id"] for member in team["members"]}
    if any(mid not in valid_member_ids for mid in access_in.allowed_member_ids):
        raise HTTPException(status_code=400, detail="Invalid member IDs in access list")

    await Database.db.documents.update_one(
        {"_id": ObjectId(doc_id)},
        {"$set": {"allowed_member_ids": access_in.allowed_member_ids}},
    )
    doc["allowed_member_ids"] = access_in.allowed_member_ids

    return Document(
        id=str(doc["_id"]),
        team_id=doc["team_id"],
        name=doc["name"],
        original_filename=doc["original_filename"],
        file_size=doc["file_size"],
        mime_type=doc["mime_type"],
        uploaded_by=doc["uploaded_by"],
        uploaded_by_name=doc["uploaded_by_name"],
        allowed_member_ids=doc["allowed_member_ids"],
        created_at=doc["created_at"],
    )


@router.delete("/{team_id}/documents/{doc_id}", response_model=dict)
async def delete_document(
    team_id: str,
    doc_id: str,
    current_user: User = Depends(get_current_user),
):
    team = await _get_team_with_membership(team_id, current_user.id)
    if not ObjectId.is_valid(doc_id):
        raise HTTPException(status_code=400, detail="Invalid document ID")

    doc = await Database.db.documents.find_one({"_id": ObjectId(doc_id), "team_id": team_id})
    if not doc:
        raise HTTPException(status_code=404, detail="Document not found")

    if doc["uploaded_by"] != current_user.id and not _is_organiser(team, current_user.id):
        raise HTTPException(status_code=403, detail="Only uploader or organiser can delete document")

    await Database.db.documents.delete_one({"_id": ObjectId(doc_id)})
    file_path = Path(doc["file_path"])
    if file_path.exists():
        file_path.unlink(missing_ok=True)
    return {"success": True, "message": "Document deleted"}
