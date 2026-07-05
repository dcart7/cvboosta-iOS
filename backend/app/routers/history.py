from __future__ import annotations

from datetime import datetime, timezone

from fastapi import APIRouter, Depends, HTTPException, status

from ..auth import get_current_user
from ..models import User
from ..schemas import HistoryItemResponse, HistoryResponse


router = APIRouter(prefix="/history", tags=["history"])


@router.get("", response_model=HistoryResponse)
def history_list(current_user: User = Depends(get_current_user)) -> HistoryResponse:
    del current_user
    return HistoryResponse(items=[])


@router.get("/{item_id}", response_model=HistoryItemResponse)
def history_detail(item_id: int, current_user: User = Depends(get_current_user)) -> HistoryItemResponse:
    del current_user
    raise HTTPException(
        status_code=status.HTTP_404_NOT_FOUND,
        detail=f"History item {item_id} was not found in the local backend harness.",
    )
