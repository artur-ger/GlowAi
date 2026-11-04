from __future__ import annotations

from datetime import datetime

from sqlalchemy import Boolean, DateTime, Float, ForeignKey, Integer, String, Text, func
from sqlalchemy.orm import DeclarativeBase, Mapped, mapped_column, relationship


class Base(DeclarativeBase):
    pass


class User(Base):
    __tablename__ = "users"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    email: Mapped[str] = mapped_column(String(255), unique=True, index=True, nullable=False)
    password_hash: Mapped[str] = mapped_column(String(255), nullable=False)
    display_name: Mapped[str] = mapped_column(String(120), default="", nullable=False)
    email_verified: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    email_verify_code: Mapped[str | None] = mapped_column(String(16), nullable=True)
    email_verify_expires: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    reset_code: Mapped[str | None] = mapped_column(String(16), nullable=True)
    reset_expires: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    terms_accepted_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    # Coach memory
    skin_type: Mapped[str] = mapped_column(String(64), default="", nullable=False)
    concerns_csv: Mapped[str] = mapped_column(String(500), default="", nullable=False)
    owned_items_csv: Mapped[str] = mapped_column(String(500), default="", nullable=False)
    avoid_items_csv: Mapped[str] = mapped_column(String(500), default="", nullable=False)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())

    checks: Mapped[list[SkinCheck]] = relationship(back_populates="user", cascade="all, delete-orphan")
    trips: Mapped[list[Trip]] = relationship(back_populates="user", cascade="all, delete-orphan")


class Trip(Base):
    __tablename__ = "trips"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), index=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), onupdate=func.now()
    )
    home_city: Mapped[str] = mapped_column(String(120), default="")
    dest_city: Mapped[str] = mapped_column(String(120), default="")
    home_lat: Mapped[float | None] = mapped_column(Float, nullable=True)
    home_lon: Mapped[float | None] = mapped_column(Float, nullable=True)
    dest_lat: Mapped[float | None] = mapped_column(Float, nullable=True)
    dest_lon: Mapped[float | None] = mapped_column(Float, nullable=True)
    trip_start: Mapped[str] = mapped_column(String(16), default="")
    trip_end: Mapped[str] = mapped_column(String(16), default="")
    # pre_trip | on_site | return_home | done
    status: Mapped[str] = mapped_column(String(32), default="pre_trip", index=True)
    latest_check_id: Mapped[int | None] = mapped_column(Integer, nullable=True)
    is_active: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)

    user: Mapped[User] = relationship(back_populates="trips")
    checks: Mapped[list[SkinCheck]] = relationship(back_populates="trip")


class SkinCheck(Base):
    __tablename__ = "skin_checks"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), index=True)
    trip_id: Mapped[int | None] = mapped_column(
        ForeignKey("trips.id", ondelete="SET NULL"), nullable=True, index=True
    )
    parent_check_id: Mapped[int | None] = mapped_column(
        ForeignKey("skin_checks.id", ondelete="SET NULL"), nullable=True, index=True
    )
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
    remind_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    remind_sent_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    mode: Mapped[str] = mapped_column(String(32), default="pre_trip")
    home_city: Mapped[str] = mapped_column(String(120), default="")
    dest_city: Mapped[str] = mapped_column(String(120), default="")
    forecast_summary: Mapped[str] = mapped_column(Text, default="")
    engine: Mapped[str] = mapped_column(String(32), default="rule_based")
    payload_json: Mapped[str] = mapped_column(Text, nullable=False)

    user: Mapped[User] = relationship(back_populates="checks")
    trip: Mapped[Trip | None] = relationship(back_populates="checks")
    messages: Mapped[list[ChatMessage]] = relationship(
        back_populates="check", cascade="all, delete-orphan", order_by="ChatMessage.id"
    )
    checkins: Mapped[list[SkinCheckIn]] = relationship(
        back_populates="check", cascade="all, delete-orphan", order_by="SkinCheckIn.id"
    )


class SkinCheckIn(Base):
    __tablename__ = "skin_checkins"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    check_id: Mapped[int] = mapped_column(ForeignKey("skin_checks.id", ondelete="CASCADE"), index=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
    dryness: Mapped[int] = mapped_column(Integer, default=3)
    oiliness: Mapped[int] = mapped_column(Integer, default=3)
    calmness: Mapped[int] = mapped_column(Integer, default=3)
    redness: Mapped[int] = mapped_column(Integer, default=3)
    note: Mapped[str] = mapped_column(String(500), default="")
    advice: Mapped[str] = mapped_column(Text, default="")
    revised_check_id: Mapped[int | None] = mapped_column(Integer, nullable=True)

    check: Mapped[SkinCheck] = relationship(back_populates="checkins")


class ChatMessage(Base):
    __tablename__ = "chat_messages"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    check_id: Mapped[int] = mapped_column(ForeignKey("skin_checks.id", ondelete="CASCADE"), index=True)
    role: Mapped[str] = mapped_column(String(16), nullable=False)  # user | assistant | system
    text: Mapped[str] = mapped_column(Text, nullable=False)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())

    check: Mapped[SkinCheck] = relationship(back_populates="messages")
