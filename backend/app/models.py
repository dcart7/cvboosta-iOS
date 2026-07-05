from __future__ import annotations

from datetime import datetime, timezone

from sqlalchemy import DateTime, ForeignKey, Integer, String, Text
from sqlalchemy.orm import Mapped, mapped_column, relationship

from .database import Base


def utc_now() -> datetime:
    return datetime.now(timezone.utc)


class User(Base):
    __tablename__ = "users"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    email: Mapped[str] = mapped_column(String(255), unique=True, index=True)
    password_hash: Mapped[str | None] = mapped_column(String(255), nullable=True)
    full_name: Mapped[str | None] = mapped_column(String(120), nullable=True)
    apple_subject: Mapped[str | None] = mapped_column(String(255), nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utc_now)

    tokens: Mapped[list["AccessToken"]] = relationship(back_populates="user", cascade="all, delete-orphan")
    tracker_folders: Mapped[list["TrackerFolder"]] = relationship(back_populates="user", cascade="all, delete-orphan")
    tracker_applications: Mapped[list["TrackerApplication"]] = relationship(back_populates="user", cascade="all, delete-orphan")


class AccessToken(Base):
    __tablename__ = "access_tokens"

    token: Mapped[str] = mapped_column(String(255), primary_key=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), index=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utc_now)

    user: Mapped[User] = relationship(back_populates="tokens")


class TrackerFolder(Base):
    __tablename__ = "tracker_folders"

    id: Mapped[str] = mapped_column(String(36), primary_key=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), index=True)
    name: Mapped[str] = mapped_column(String(120))
    emoji: Mapped[str] = mapped_column(String(16), default="🗂")
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utc_now)
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utc_now, onupdate=utc_now)

    user: Mapped[User] = relationship(back_populates="tracker_folders")
    applications: Mapped[list["TrackerApplication"]] = relationship(back_populates="folder")


class TrackerApplication(Base):
    __tablename__ = "tracker_applications"

    id: Mapped[str] = mapped_column(String(36), primary_key=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), index=True)
    company: Mapped[str] = mapped_column(String(120))
    role: Mapped[str] = mapped_column(String(120))
    status: Mapped[str] = mapped_column(String(32), index=True)
    source: Mapped[str | None] = mapped_column(String(64), default="iOS")
    applied_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utc_now)
    interview_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    notes: Mapped[str | None] = mapped_column(Text, nullable=True)
    resume_used: Mapped[str | None] = mapped_column(String(255), nullable=True)
    job_link: Mapped[str | None] = mapped_column(Text, nullable=True)
    folder_id: Mapped[str | None] = mapped_column(ForeignKey("tracker_folders.id", ondelete="SET NULL"), nullable=True, index=True)
    ats_score: Mapped[int | None] = mapped_column(Integer, nullable=True)
    interview_reflection_rating: Mapped[int | None] = mapped_column(Integer, nullable=True)
    interview_reflection_outcome: Mapped[str | None] = mapped_column(String(64), nullable=True)
    interview_reflection_notes: Mapped[str | None] = mapped_column(Text, nullable=True)
    interview_reflection_submitted_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utc_now)
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utc_now, onupdate=utc_now)

    user: Mapped[User] = relationship(back_populates="tracker_applications")
    folder: Mapped[TrackerFolder | None] = relationship(back_populates="applications")
