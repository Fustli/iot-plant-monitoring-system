from sqlalchemy import Column, Integer, String, Boolean, DateTime, Index
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func
from db.base import Base


class User(Base):
    __tablename__ = 'users'

    id = Column(Integer, primary_key=True, autoincrement=True)
    email = Column(String(255), unique=True, nullable=False, index=True)
    username = Column(String(100), unique=True, nullable=False, index=True)
    password_hash = Column(String(255), nullable=False)
    first_name = Column(String(100))
    last_name = Column(String(100))
    phone_number = Column(String(20))
    is_active = Column(Boolean, default=True, nullable=False, index=True)
    is_verified = Column(Boolean, default=False, nullable=False)
    created_at = Column(DateTime(timezone=True), server_default=func.now(), nullable=False)
    updated_at = Column(DateTime(timezone=True), server_default=func.now(), 
                       onupdate=func.now(), nullable=False)
    last_login = Column(DateTime(timezone=True))

    devices = relationship('Device', back_populates='owner', cascade='all, delete-orphan')
    plants = relationship('Plant', back_populates='owner', cascade='all, delete-orphan')
    alert_rules = relationship('AlertRule', back_populates='user', cascade='all, delete-orphan')
    alerts = relationship('Alert', back_populates='user', cascade='all, delete-orphan')

    __table_args__ = (
        Index('idx_user_email', 'email'),
        Index('idx_user_username', 'username'),
        Index('idx_user_is_active', 'is_active'),
    )

    def __repr__(self):
        return f'<User {self.username}>'
