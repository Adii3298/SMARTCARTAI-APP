from pydantic import BaseModel, Field
from typing import List, Optional
from datetime import datetime

# Auth Schemas
class CaptchaResponse(BaseModel):
    captcha_id: str
    image_base64: str

class UserRegister(BaseModel):
    role: str  # admin, customer, merchant, delivery
    name: str
    mobile: str
    password: Optional[str] = None
    email: Optional[str] = None
    address: Optional[str] = None
    area: Optional[str] = "Indiranagar"
    pincode: Optional[str] = "560038"
    
    # Merchant fields
    store_name: Optional[str] = None
    store_address: Optional[str] = None
    upi_id: Optional[str] = None
    
    # Delivery Partner fields
    vehicle_type: Optional[str] = "Bike"
    vehicle_number: Optional[str] = None

class UserLogin(BaseModel):
    login_id: str  # Can be user_id or mobile number
    password: str
    captcha_id: str
    captcha_text: str
    portal: Optional[str] = None  # e.g., 'customer', 'merchant', 'delivery', 'admin'

class ForgotPasswordRequest(BaseModel):
    login_id: str  # user_id (e.g. CUST1001, MERC2001, DELV3001) or mobile number
    portal: Optional[str] = None

class ResetPasswordRequest(BaseModel):
    login_id: str  # user_id or mobile number
    otp: str  # 6-digit verification code
    new_password: str

class UserProfileUpdate(BaseModel):
    name: Optional[str] = None
    email: Optional[str] = None
    address: Optional[str] = None
    area: Optional[str] = None
    pincode: Optional[str] = None
    store_name: Optional[str] = None
    store_address: Optional[str] = None
    upi_id: Optional[str] = None
    vehicle_type: Optional[str] = None
    vehicle_number: Optional[str] = None
    is_online: Optional[bool] = None

# OCR and NLP Schemas
class ExtractedGroceryItem(BaseModel):
    name: str
    brand: Optional[str] = None
    quantity: float = 1.0
    unit: str = "packet"
    category: Optional[str] = "General"
    confidence: Optional[float] = 0.95

class OCRParseResponse(BaseModel):
    raw_text: str
    annotated_image: Optional[str] = None
    items: List[ExtractedGroceryItem]

# Store & Inventory Schemas
class StoreInventoryCheckItem(BaseModel):
    name: str
    quantity: float = 1.0
    unit: str = "packet"

class StoreAvailabilityRequest(BaseModel):
    store_id: int
    items: List[StoreInventoryCheckItem]

class CompareStoresRequest(BaseModel):
    items: List[StoreInventoryCheckItem]
    area: Optional[str] = None

class InventoryItemModel(BaseModel):
    id: Optional[int] = None
    name: str
    brand: Optional[str] = None
    category: str
    unit: str
    price: float
    stock_quantity: float
    is_in_stock: bool

# Order Flow Schemas
class CreateOrderRequest(BaseModel):
    store_id: int
    delivery_address: str
    payment_mode: Optional[str] = "COD"  # COD or UPI
    notes: Optional[str] = None
    items: List[ExtractedGroceryItem]

class MerchantPackItem(BaseModel):
    item_id: int
    packed_quantity: float
    unit_price: float
    is_available: bool
    notes: Optional[str] = None

class MerchantConfirmRequest(BaseModel):
    order_id: int
    items: List[MerchantPackItem]
    total_amount: float
    notes: Optional[str] = None

class CustomerAcceptRequest(BaseModel):
    order_id: int
    payment_mode: str  # COD or UPI
    transaction_ref: Optional[str] = None  # UTR / UPI Ref ID or cash note

class DeliveryAcceptRequest(BaseModel):
    order_id: int

class DeliveryVerifyRequest(BaseModel):
    order_id: int
    delivery_code: str  # 6-digit verification code
