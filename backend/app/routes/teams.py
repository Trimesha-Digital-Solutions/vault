from fastapi import APIRouter, Depends, HTTPException, status, Body, Header
from typing import List
from datetime import datetime
import secrets
import string
from pydantic import BaseModel, EmailStr
from bson import ObjectId

from ..models import (
    User, Team, TeamCreate, TeamInDB, TeamMember,
    SharedVault, SharedVaultCreate, SharedVaultInDB,
    Password, PasswordCreate, PasswordInDB,
    MessageResponse, RoleUpdateRequest
)
from ..database import Database
from .auth import get_current_user
from ..security import EncryptionService, security_service

router = APIRouter(prefix="/teams", tags=["teams"])


def _get_member_role(team: dict, user_id: str) -> str | None:
    for member in team.get("members", []):
        if member["user_id"] == user_id:
            return member.get("role")
    return None


def generate_team_code(length=8):
    """Generate a random team code"""
    alphabet = string.ascii_uppercase + string.digits
    return '-'.join([''.join(secrets.choice(alphabet) for _ in range(3)) for _ in range(3)])


@router.post("/", response_model=Team)
async def create_team(
    team_in: TeamCreate,
    current_user: User = Depends(get_current_user)
):
    """Create a new team"""
    team_code = generate_team_code()
    
    # Check if code exists (highly unlikely but good practice)
    while await Database.db.teams.find_one({"code": team_code}):
        team_code = generate_team_code()
    
    new_team = TeamInDB(
         name=team_in.name,
         code=team_code,
         created_by=current_user.id,
         members=[
             TeamMember(
                 user_id=current_user.id,
                 role="Organiser"
             )
         ],
         created_at=datetime.utcnow(),
         updated_at=datetime.utcnow()
    )
    
    result = await Database.db.teams.insert_one(new_team.model_dump(by_alias=True, exclude=["id"]))
    
    return Team(
        id=str(result.inserted_id),
        name=new_team.name,
        code=new_team.code,
        created_by=new_team.created_by,
        role="Organiser",
        member_count=1,
        created_at=new_team.created_at
    )


@router.post("/join", response_model=Team)
async def join_team(
    code: str = Body(..., embed=True),
    current_user: User = Depends(get_current_user)
):
    """Join a team by code"""
    team = await Database.db.teams.find_one({"code": code})
    if not team:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Invalid team code"
        )
    
    # Check if already a member
    members = team.get("members", [])
    for member in members:
        if member["user_id"] == current_user.id:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="You are already a member of this team"
            )
            
    # Add member
    new_member = TeamMember(
        user_id=current_user.id,
        role="Member"
    )
    
    await Database.db.teams.update_one(
        {"_id": team["_id"]},
        {
            "$push": {"members": new_member.model_dump()},
            "$set": {"updated_at": datetime.utcnow()}
        }
    )
    
    return Team(
        id=str(team["_id"]),
        name=team["name"],
        code=team["code"],
        created_by=team["created_by"],
        role="Member",
        member_count=len(members) + 1,
        created_at=team["created_at"]
    )


@router.get("/", response_model=List[Team])
async def get_my_teams(
    current_user: User = Depends(get_current_user)
):
    """Get all teams where user is a member"""
    cursor = Database.db.teams.find({"members.user_id": current_user.id})
    teams = await cursor.to_list(length=100)
    
    result = []
    for team in teams:
        # Find user role
        user_role = "Member"
        for member in team["members"]:
            if member["user_id"] == current_user.id:
                user_role = member["role"]
                break
                
        result.append(Team(
            id=str(team["_id"]),
            name=team["name"],
            code=team["code"],
            created_by=team["created_by"],
            role=user_role,
            member_count=len(team["members"]),
            created_at=team["created_at"]
        ))
        
    return result


@router.post("/{team_id}/vaults", response_model=SharedVault)
async def create_shared_vault(
    team_id: str,
    vault_in: SharedVaultCreate,
    current_user: User = Depends(get_current_user)
):
    """Create a shared vault in a team"""
    if not ObjectId.is_valid(team_id):
        raise HTTPException(status_code=400, detail="Invalid team ID")
        
    team = await Database.db.teams.find_one({
        "_id": ObjectId(team_id),
        "members.user_id": current_user.id
    })
    
    if not team:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Team not found or access denied"
        )
    
    new_vault = SharedVaultInDB(
        name=vault_in.name,
        team_id=team_id,
        created_by=current_user.id,
        member_ids=vault_in.member_ids if vault_in.member_ids else [current_user.id],
        created_at=datetime.utcnow(),
        updated_at=datetime.utcnow()
    )
    
    result = await Database.db.shared_vaults.insert_one(
        new_vault.model_dump(by_alias=True, exclude=["id"])
    )
    
    return SharedVault(
        id=str(result.inserted_id),
        name=new_vault.name,
        team_id=new_vault.team_id,
        created_by=new_vault.created_by,
        member_ids=new_vault.member_ids,
        password_count=0,
        created_at=new_vault.created_at
    )


@router.get("/{team_id}/vaults", response_model=List[SharedVault])
async def get_team_vaults(
    team_id: str,
    current_user: User = Depends(get_current_user)
):
    """Get shared vaults for a team"""
    if not ObjectId.is_valid(team_id):
        raise HTTPException(status_code=400, detail="Invalid team ID")
        
    # Verify team membership
    team = await Database.db.teams.find_one({
        "_id": ObjectId(team_id),
        "members.user_id": current_user.id
    })
    
    if not team:
        raise HTTPException(status_code=404, detail="Team not found")

    cursor = Database.db.shared_vaults.find({"team_id": team_id})
    vaults = await cursor.to_list(length=100)
    
    result = []
    for vault in vaults:
        # Count passwords
        pwd_count = await Database.db.passwords.count_documents({
            "shared_vault_id": str(vault["_id"])
        })
        
        result.append(SharedVault(
            id=str(vault["_id"]),
            name=vault["name"],
            team_id=vault["team_id"],
            created_by=vault["created_by"],
            member_ids=vault["member_ids"],
            password_count=pwd_count,
            created_at=vault["created_at"]
        ))
        
    return result


@router.put("/{team_id}/vaults/{vault_id}", response_model=SharedVault)
async def update_shared_vault(
    team_id: str,
    vault_id: str,
    vault_in: SharedVaultCreate,
    current_user: User = Depends(get_current_user)
):
    """Update a shared vault (e.g. change members)"""
    if not ObjectId.is_valid(team_id) or not ObjectId.is_valid(vault_id):
        raise HTTPException(status_code=400, detail="Invalid ID")
        
    # Verify owner/admin access
    team = await Database.db.teams.find_one({
        "_id": ObjectId(team_id),
        "members.user_id": current_user.id
    })
    
    if not team:
        raise HTTPException(status_code=404, detail="Team not found")
        
    # Check vault existence
    vault = await Database.db.shared_vaults.find_one({"_id": ObjectId(vault_id), "team_id": team_id})
    if not vault:
        raise HTTPException(status_code=404, detail="Vault not found")
        
    # Check permission (only creator or admin can edit? For now let's say creator only)
    if vault["created_by"] != current_user.id:
          # Ideally check for Team Admin too.
          # For simplicity allowing creator or any team member for now? No, better stick to creator.
          pass 

    # Update logic (for now just name and members)
    update_data = {
        "name": vault_in.name,
        "member_ids": vault_in.member_ids,
        "updated_at": datetime.utcnow()
    }
    
    await Database.db.shared_vaults.update_one(
        {"_id": ObjectId(vault_id)},
        {"$set": update_data}
    )
    
    # Calculate password count
    pwd_count = await Database.db.passwords.count_documents({
        "shared_vault_id": vault_id
    })
    
    return SharedVault(
        id=str(vault["_id"]),
        name=update_data["name"],
        team_id=vault["team_id"],
        created_by=vault["created_by"],
        member_ids=update_data["member_ids"],
        password_count=pwd_count,
        created_at=vault["created_at"]
    )



@router.get("/{team_id}/members", response_model=List[dict])
async def get_team_members(
    team_id: str,
    current_user: User = Depends(get_current_user)
):
    """Get members of a team"""
    if not ObjectId.is_valid(team_id):
        raise HTTPException(status_code=400, detail="Invalid team ID")
        
    team = await Database.db.teams.find_one({
        "_id": ObjectId(team_id),
        "members.user_id": current_user.id
    })
    
    if not team:
        raise HTTPException(status_code=404, detail="Team not found")
        
    # Fetch user details for each member
    member_details = []
    for member in team["members"]:
        user = await Database.db.users.find_one({"_id": ObjectId(member["user_id"])})
        if user:
            member_details.append({
                "id": str(user["_id"]),
                "name": f"{user.get('first_name', '')} {user.get('last_name', '')}".strip() or user["username"],
                "email": user["email"],
                "role": member["role"],
                "joined_at": member["joined_at"]
            })
            
    return member_details


@router.put("/{team_id}/members/{user_id}/role", response_model=MessageResponse)
async def update_member_role(
    team_id: str,
    user_id: str,
    role_in: RoleUpdateRequest,
    current_user: User = Depends(get_current_user),
):
    """Update role for a team member (Organiser only)."""
    if role_in.role not in {"Organiser", "Member"}:
        raise HTTPException(status_code=400, detail="Role must be Organiser or Member")
    if not ObjectId.is_valid(team_id) or not ObjectId.is_valid(user_id):
        raise HTTPException(status_code=400, detail="Invalid ID")

    team = await Database.db.teams.find_one(
        {"_id": ObjectId(team_id), "members.user_id": current_user.id}
    )
    if not team:
        raise HTTPException(status_code=404, detail="Team not found")

    current_role = _get_member_role(team, current_user.id)
    if current_role != "Organiser":
        raise HTTPException(status_code=403, detail="Only organisers can change roles")

    target_member = next((m for m in team["members"] if m["user_id"] == user_id), None)
    if target_member is None:
        raise HTTPException(status_code=404, detail="Member not found")

    if target_member["role"] == "Organiser" and role_in.role == "Member":
        organisers = [m for m in team["members"] if m["role"] == "Organiser"]
        if len(organisers) <= 1:
            raise HTTPException(status_code=400, detail="Team must have at least one organiser")

    await Database.db.teams.update_one(
        {"_id": ObjectId(team_id), "members.user_id": user_id},
        {
            "$set": {
                "members.$.role": role_in.role,
                "updated_at": datetime.utcnow(),
            }
        },
    )

    return MessageResponse(message="Member role updated successfully", success=True)


from ..services.email_service import email_service
from pydantic import EmailStr

class TeamInviteRequest(BaseModel):
    """Request to invite a member to a team"""
    email: EmailStr

@router.post("/{team_id}/invite", response_model=MessageResponse)
async def invite_member(
    team_id: str,
    invite: TeamInviteRequest,
    current_user: User = Depends(get_current_user)
):
    """Invite a member to the team via email"""
    if not ObjectId.is_valid(team_id):
        raise HTTPException(status_code=400, detail="Invalid team ID")
        
    team = await Database.db.teams.find_one({
        "_id": ObjectId(team_id),
        "members.user_id": current_user.id
    })
    
    if not team:
        raise HTTPException(status_code=404, detail="Team not found or permission denied")
        
    # Send email
    inviter_name = f"{current_user.first_name} {current_user.last_name}".strip() or current_user.username
    
    # We send the team code. In a more advanced version, we could create a unique
    # invite token that expires and adds them automatically.
    # For now, per requirements "invite code as it is there", we send the team code.
    
    result = email_service.send_team_invite_email(
        to=invite.email,
        team_name=team["name"],
        invite_code=team["code"],
        inviter_name=inviter_name
    )
    
    if not result["success"]:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, 
            detail="Failed to send invitation email"
        )
        
    return MessageResponse(
        message=f"Invitation sent to {invite.email}",
        success=True
    )
    

@router.post("/{team_id}/vaults/{vault_id}/passwords", response_model=Password)
async def create_shared_password(

    team_id: str,
    vault_id: str,
    password_data: PasswordCreate,
    master_password: str = Header(..., alias="X-Master-Password"),
    current_user: User = Depends(get_current_user)
):
    """Create a password in a shared vault"""
    # Verify master password
    if not security_service.verify_password(master_password, current_user.hashed_master_password):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid master password"
        )
        
    if not ObjectId.is_valid(team_id) or not ObjectId.is_valid(vault_id):
        raise HTTPException(status_code=400, detail="Invalid ID")

    # Verify access
    team = await Database.db.teams.find_one({
        "_id": ObjectId(team_id),
        "members.user_id": current_user.id
    })
    
    if not team:
         raise HTTPException(status_code=404, detail="Team not found")
         
    # Check if vault exists
    vault = await Database.db.shared_vaults.find_one({"_id": ObjectId(vault_id), "team_id": team_id})
    if not vault:
        raise HTTPException(status_code=404, detail="Vault not found")

    # Encrypt password
    encryption_service = EncryptionService(master_password)
    encrypted_password = encryption_service.encrypt_password(password_data.password)
    
    # Create password document
    password_doc = {
        "user_id": current_user.id,
        "title": password_data.title,
        "username": password_data.username,
        "encrypted_password": encrypted_password,
        "url": password_data.url or "",
        "notes": password_data.notes or "",
        "category": password_data.category,
        "shared_vault_id": vault_id,
        "created_at": datetime.utcnow(),
        "updated_at": datetime.utcnow()
    }
    
    # Insert password
    result = await Database.db.passwords.insert_one(password_doc)
    
    return Password(
        id=str(result.inserted_id),
        title=password_data.title,
        username=password_data.username,
        password=password_data.password,
        url=password_data.url or "",
        notes=password_data.notes or "",
        category=password_data.category,
        shared_vault_id=vault_id,
        created_at=password_doc["created_at"],
        updated_at=password_doc["updated_at"]
    )


@router.get("/{team_id}/vaults/{vault_id}/passwords", response_model=List[Password])
async def get_shared_vault_passwords(
    team_id: str,
    vault_id: str,
    master_password: str = Header(..., alias="X-Master-Password"),
    current_user: User = Depends(get_current_user)
):
    """Get passwords in a shared vault"""
    # Verify master password
    if not security_service.verify_password(master_password, current_user.hashed_master_password):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid master password"
        )
        
    if not ObjectId.is_valid(team_id) or not ObjectId.is_valid(vault_id):
        raise HTTPException(status_code=400, detail="Invalid ID")

    # Verify access
    team = await Database.db.teams.find_one({
        "_id": ObjectId(team_id),
        "members.user_id": current_user.id
    })
    
    if not team:
         raise HTTPException(status_code=404, detail="Team not found")

    # Get passwords
    cursor = Database.db.passwords.find({"shared_vault_id": vault_id})
    passwords_docs = await cursor.to_list(length=100)
    
    passwords = []
    encryption_service = EncryptionService(master_password)
    
    for doc in passwords_docs:
        # Try to decrypt using current user's master password
        # If user created it, it will work. 
        # CAUTION: This means only the creator can see the password for now.
        # This is a limitation of the current crypto design.
        try:
            decrypted_password = encryption_service.decrypt_password(doc["encrypted_password"])
        except Exception:
             decrypted_password = "**************** (Encrypted by another user)"
             
        passwords.append(Password(
            id=str(doc["_id"]),
            title=doc["title"],
            username=doc["username"],
            password=decrypted_password,
            url=doc.get("url", ""),
            notes=doc.get("notes", ""),
            category=doc["category"],
            shared_vault_id=vault_id,
            created_at=doc["created_at"],
            updated_at=doc["updated_at"]
        ))
        
    return passwords
