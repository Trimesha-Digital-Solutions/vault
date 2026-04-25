from collections import defaultdict
from typing import Any

import socketio


sio = socketio.AsyncServer(async_mode="asgi", cors_allowed_origins="*")


class SocketManager:
    """Tracks Socket.IO room membership by team."""

    def __init__(self) -> None:
        self._sid_team: dict[str, str] = {}
        self._team_sids: dict[str, set[str]] = defaultdict(set)

    async def join_team(self, sid: str, team_id: str) -> None:
        await sio.enter_room(sid, team_id)
        self._sid_team[sid] = team_id
        self._team_sids[team_id].add(sid)

    async def leave_team(self, sid: str) -> None:
        team_id = self._sid_team.pop(sid, None)
        if not team_id:
            return
        await sio.leave_room(sid, team_id)
        if team_id in self._team_sids:
            self._team_sids[team_id].discard(sid)
            if not self._team_sids[team_id]:
                del self._team_sids[team_id]

    async def emit_to_team(self, team_id: str, event: str, payload: dict[str, Any]) -> None:
        await sio.emit(event, payload, room=team_id)


socket_manager = SocketManager()


@sio.event
async def connect(sid: str, environ: dict, auth: dict | None = None):
    return True


@sio.event
async def disconnect(sid: str):
    await socket_manager.leave_team(sid)


@sio.event
async def join_team(sid: str, data: dict):
    team_id = data.get("team_id")
    if not team_id:
        return
    await socket_manager.join_team(sid, team_id)
    await socket_manager.emit_to_team(team_id, "presence", {"sid": sid, "status": "online"})


@sio.event
async def leave_team(sid: str, data: dict | None = None):
    await socket_manager.leave_team(sid)


@sio.event
async def typing_start(sid: str, data: dict):
    team_id = data.get("team_id")
    user_id = data.get("user_id")
    if team_id and user_id:
        await socket_manager.emit_to_team(
            team_id, "typing", {"team_id": team_id, "user_id": user_id, "typing": True}
        )


@sio.event
async def typing_stop(sid: str, data: dict):
    team_id = data.get("team_id")
    user_id = data.get("user_id")
    if team_id and user_id:
        await socket_manager.emit_to_team(
            team_id, "typing", {"team_id": team_id, "user_id": user_id, "typing": False}
        )
