"""Podcast conversation routes."""
# ruff: noqa

import logging

from fastapi import APIRouter, Depends, HTTPException, Query, status

from app.core.exceptions import EpisodeNotFoundError

from app.core.auth import require_api_key
from app.domains.podcast.routes.dependencies import (
    get_conversation_service,
    get_podcast_episode_service,
)
from app.domains.podcast.routes.response_assemblers import (
    build_conversation_history_response,
    build_conversation_session_list_response,
)
from app.domains.podcast.conversation_service import ConversationService
from app.domains.podcast.schemas import (
    ConversationSessionCreateRequest,
    ConversationSessionListResponse,
    ConversationSessionResponse,
    PodcastConversationClearResponse,
    PodcastConversationHistoryResponse,
    PodcastConversationSendRequest,
    PodcastConversationSendResponse,
)
from app.domains.podcast.services.episode_service import PodcastEpisodeService


router = APIRouter(prefix="")
logger = logging.getLogger(__name__)


# === Session Management ===


@router.get(
    "/episodes/{episode_id}/conversation-sessions",
    response_model=ConversationSessionListResponse,
    summary="List conversation sessions",
    description="List all conversation sessions for a podcast episode",
)
async def list_conversation_sessions(
    episode_id: int,
    episode_service: PodcastEpisodeService = Depends(get_podcast_episode_service),
    user_id: int = Depends(require_api_key),
    conversation_service: ConversationService = Depends(get_conversation_service),
):
    try:
        episode = await episode_service.get_episode_by_id(episode_id)
        if not episode:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"Episode {episode_id} not found",
            )

        sessions = await conversation_service.get_sessions(
            episode_id=episode_id,
            user_id=user_id,
        )

        return build_conversation_session_list_response(sessions)
    except HTTPException:
        raise
    except Exception as exc:
        logger.error("Failed to list sessions for episode %s: %s", episode_id, exc)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to list sessions",
        )


@router.post(
    "/episodes/{episode_id}/conversation-sessions",
    status_code=status.HTTP_201_CREATED,
    response_model=ConversationSessionResponse,
    summary="Create conversation session",
    description="Create a new conversation session for a podcast episode",
)
async def create_conversation_session(
    episode_id: int,
    request: ConversationSessionCreateRequest,
    episode_service: PodcastEpisodeService = Depends(get_podcast_episode_service),
    user_id: int = Depends(require_api_key),
    conversation_service: ConversationService = Depends(get_conversation_service),
):
    try:
        episode = await episode_service.get_episode_by_id(episode_id)
        if not episode:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"Episode {episode_id} not found",
            )

        session = await conversation_service.create_session(
            episode_id=episode_id,
            user_id=user_id,
            title=request.title,
        )

        return ConversationSessionResponse(**session)
    except HTTPException:
        raise
    except Exception as exc:
        logger.error("Failed to create session for episode %s: %s", episode_id, exc)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to create session",
        )


@router.delete(
    "/episodes/{episode_id}/conversation-sessions/{session_id}",
    response_model=PodcastConversationClearResponse,
    summary="Delete conversation session",
    description="Delete a conversation session and all its messages",
)
async def delete_conversation_session(
    episode_id: int,
    session_id: int,
    user_id: int = Depends(require_api_key),
    conversation_service: ConversationService = Depends(get_conversation_service),
):
    try:
        deleted_count = await conversation_service.delete_session(
            session_id=session_id,
            user_id=user_id,
        )

        return PodcastConversationClearResponse(
            episode_id=episode_id,
            session_id=session_id,
            deleted_count=deleted_count,
        )
    except HTTPException:
        raise
    except Exception as exc:
        logger.error("Failed to delete session %s: %s", session_id, exc)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to delete session",
        )


# === Conversation Messages ===


@router.get(
    "/episodes/{episode_id}/conversations",
    response_model=PodcastConversationHistoryResponse,
    summary="Get conversation history",
    description="Get conversation history for a podcast episode",
)
async def get_conversation_history(
    episode_id: int,
    session_id: int | None = Query(None, description="Session ID to filter by"),
    limit: int = Query(50, ge=1, le=200, description="Number of messages"),
    episode_service: PodcastEpisodeService = Depends(get_podcast_episode_service),
    user_id: int = Depends(require_api_key),
    conversation_service: ConversationService = Depends(get_conversation_service),
):
    try:
        episode = await episode_service.get_episode_by_id(episode_id)
        if not episode:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"Episode {episode_id} not found",
            )

        messages = await conversation_service.get_conversation_history(
            episode_id=episode_id,
            user_id=user_id,
            session_id=session_id,
            limit=limit,
        )

        return build_conversation_history_response(
            episode_id=episode_id,
            session_id=session_id,
            messages=messages,
        )
    except HTTPException:
        raise
    except Exception as exc:
        logger.error(
            "Failed to get conversation history for episode %s: %s",
            episode_id,
            exc,
        )
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to get conversation history",
        )


@router.post(
    "/episodes/{episode_id}/conversations",
    status_code=status.HTTP_201_CREATED,
    response_model=PodcastConversationSendResponse,
    summary="Send conversation message",
    description="Send a message and get AI response with context",
)
async def send_conversation_message(
    episode_id: int,
    request: PodcastConversationSendRequest,
    episode_service: PodcastEpisodeService = Depends(get_podcast_episode_service),
    user_id: int = Depends(require_api_key),
    conversation_service: ConversationService = Depends(get_conversation_service),
):
    try:
        episode = await episode_service.get_episode_by_id(episode_id)
        if not episode:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"Episode {episode_id} not found",
            )

        response = await conversation_service.send_message(
            episode_id=episode_id,
            user_id=user_id,
            user_message=request.message,
            model_name=request.model_name,
            session_id=request.session_id,
        )

        return PodcastConversationSendResponse(**response)
    except EpisodeNotFoundError:
        raise HTTPException(status_code=404, detail="Episode not found")
    except HTTPException:
        raise
    except Exception as exc:
        logger.error("Failed to send message for episode %s: %s", episode_id, exc)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to send message",
        )


@router.delete(
    "/episodes/{episode_id}/conversations",
    response_model=PodcastConversationClearResponse,
    summary="Clear conversation history",
    description="Clear conversation history for a podcast episode",
)
async def clear_conversation_history(
    episode_id: int,
    session_id: int | None = Query(None, description="Session ID to clear"),
    episode_service: PodcastEpisodeService = Depends(get_podcast_episode_service),
    user_id: int = Depends(require_api_key),
    conversation_service: ConversationService = Depends(get_conversation_service),
):
    try:
        episode = await episode_service.get_episode_by_id(episode_id)
        if not episode:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"Episode {episode_id} not found",
            )

        deleted_count = await conversation_service.clear_conversation_history(
            episode_id=episode_id,
            user_id=user_id,
            session_id=session_id,
        )

        return PodcastConversationClearResponse(
            episode_id=episode_id,
            session_id=session_id,
            deleted_count=deleted_count,
        )
    except HTTPException:
        raise
    except Exception as exc:
        logger.error(
            "Failed to clear conversation history for episode %s: %s",
            episode_id,
            exc,
        )
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to clear conversation history",
        )
