import datetime
from sqlalchemy import Column, Integer, String, Float, Boolean, DateTime, ForeignKey, Text
from sqlalchemy.orm import relationship
from .database import Base

def utcnow():
    return datetime.datetime.now(datetime.timezone.utc).replace(tzinfo=None)

class User(Base):
    __tablename__ = "users"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(String(50), unique=True, index=True)
    name = Column(String(100), nullable=False)
    mobile = Column(String(20), unique=True, index=True, nullable=False)
    email = Column(String(100), nullable=True)
    password_hash = Column(String(255), nullable=False)
    role = Column(String(20), nullable=False)  # admin, customer, merchant, delivery
    address = Column(String(255), nullable=True)
    area = Column(String(100), nullable=True)
    pincode = Column(String(10), nullable=True)
    
    # Merchant-specific attributes
    store_name = Column(String(150), nullable=True)
    store_address = Column(String(255), nullable=True)
    upi_id = Column(String(50), nullable=True)
    
    # Delivery partner-specific attributes
    vehicle_type = Column(String(50), nullable=True)  # Bike, Scooter, Bicycle
    vehicle_number = Column(String(50), nullable=True)
    is_online = Column(Boolean, default=True)
    
    is_active = Column(Boolean, default=True)
    created_at = Column(DateTime, default=utcnow)

    # Relationships
    stores = relationship("Store", back_populates="merchant", foreign_keys="Store.merchant_id")
    customer_orders = relationship("Order", back_populates="customer", foreign_keys="Order.customer_id")
    delivery_orders = relationship("Order", back_populates="delivery_partner", foreign_keys="Order.delivery_partner_id")


class Store(Base):
    __tablename__ = "stores"

    id = Column(Integer, primary_key=True, index=True)
    merchant_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    name = Column(String(150), nullable=False)
    owner_name = Column(String(100), nullable=False)
    phone = Column(String(20), nullable=False)
    address = Column(String(255), nullable=False)
    area = Column(String(100), nullable=False)
    pincode = Column(String(10), nullable=False)
    status = Column(String(20), default="active")  # active, closed, pending
    rating = Column(Float, default=4.8)
    node_id = Column(Integer, ForeignKey("smart_cart_nodes.id"), nullable=True)
    created_at = Column(DateTime, default=utcnow)

    # Relationships
    merchant = relationship("User", back_populates="stores", foreign_keys=[merchant_id])
    inventory = relationship("ProductInventory", back_populates="store", cascade="all, delete-orphan")
    orders = relationship("Order", back_populates="store")
    node = relationship("SmartCartNode", back_populates="stores")


class ProductInventory(Base):
    __tablename__ = "product_inventory"

    id = Column(Integer, primary_key=True, index=True)
    store_id = Column(Integer, ForeignKey("stores.id"), nullable=False)
    name = Column(String(150), nullable=False)
    brand = Column(String(100), nullable=True)
    category = Column(String(100), nullable=False)
    unit = Column(String(30), nullable=False)  # kg, g, l, ml, packet, piece
    price = Column(Float, nullable=False)
    stock_quantity = Column(Float, default=100.0)
    is_in_stock = Column(Boolean, default=True)
    updated_at = Column(DateTime, default=utcnow, onupdate=utcnow)

    # Relationships
    store = relationship("Store", back_populates="inventory")


class SmartCartNode(Base):
    __tablename__ = "smart_cart_nodes"

    id = Column(Integer, primary_key=True, index=True)
    node_code = Column(String(50), unique=True, index=True)
    name = Column(String(100), nullable=False)
    area = Column(String(100), nullable=False)
    city = Column(String(100), default="Bengaluru")
    pincode = Column(String(10), nullable=False)
    status = Column(String(20), default="operational")  # operational, maintenance
    created_at = Column(DateTime, default=utcnow)

    # Relationships
    stores = relationship("Store", back_populates="node")


class Order(Base):
    __tablename__ = "orders"

    id = Column(Integer, primary_key=True, index=True)
    order_number = Column(String(30), unique=True, index=True, nullable=False)
    customer_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    store_id = Column(Integer, ForeignKey("stores.id"), nullable=False)
    delivery_partner_id = Column(Integer, ForeignKey("users.id"), nullable=True)
    
    # Order Flow Status:
    # 1. PENDING_MERCHANT: Customer sent list, waiting for merchant packing
    # 2. PACKING_CONFIRMED: Merchant packed, finalized price, waiting customer accept
    # 3. LOOKING_FOR_DELIVERY: Customer accepted & paid/COD, waiting delivery pickup
    # 4. OUT_FOR_DELIVERY: Delivery partner accepted gig, en-route
    # 5. DELIVERED: 6-digit code verified, delivery complete
    # 6. CANCELLED: Order cancelled
    status = Column(String(30), default="PENDING_MERCHANT", index=True)
    
    total_amount = Column(Float, default=0.0)
    delivery_fee = Column(Float, default=50.0)  # Customer delivery fee at ₹50 per km (Free delivery disabled)
    payment_mode = Column(String(20), default="COD")  # COD, UPI
    payment_status = Column(String(20), default="PENDING")  # PENDING, COMPLETED
    delivery_code = Column(String(10), nullable=False)  # 6-digit delivery verification OTP
    delivery_address = Column(String(255), nullable=False)
    estimated_delivery_minutes = Column(Integer, default=15)
    notes = Column(Text, nullable=True)
    
    created_at = Column(DateTime, default=utcnow)
    confirmed_at = Column(DateTime, nullable=True)
    dispatched_at = Column(DateTime, nullable=True)
    delivered_at = Column(DateTime, nullable=True)

    # Relationships
    customer = relationship("User", back_populates="customer_orders", foreign_keys=[customer_id])
    delivery_partner = relationship("User", back_populates="delivery_orders", foreign_keys=[delivery_partner_id])
    store = relationship("Store", back_populates="orders")
    items = relationship("OrderItem", back_populates="order", cascade="all, delete-orphan")


class OrderItem(Base):
    __tablename__ = "order_items"

    id = Column(Integer, primary_key=True, index=True)
    order_id = Column(Integer, ForeignKey("orders.id"), nullable=False)
    product_name = Column(String(150), nullable=False)
    brand = Column(String(100), nullable=True)
    requested_quantity = Column(Float, default=1.0)
    requested_unit = Column(String(30), default="packet")
    packed_quantity = Column(Float, default=1.0)
    unit_price = Column(Float, default=0.0)
    subtotal = Column(Float, default=0.0)
    is_available = Column(Boolean, default=True)
    notes = Column(String(255), nullable=True)

    # Relationships
    order = relationship("Order", back_populates="items")


class ActivityLog(Base):
    __tablename__ = "activity_logs"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, nullable=True)
    role = Column(String(30), nullable=False)
    action = Column(String(100), nullable=False)
    details = Column(Text, nullable=True)
    created_at = Column(DateTime, default=utcnow)
