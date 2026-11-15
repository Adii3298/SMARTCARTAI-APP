/**
 * Smart Cart AI - Customer Flow Module
 * Implements Steps 1-15: AI Extraction, Store Availability, Packing, Delivery OTP & Live Tracking
 */

const CustomerModule = {
    extractedItems: [],
    availableStores: [],
    selectedStoreId: null,
    currentAvailability: null,
    activeOrder: null,

    init() {
        this.loadStores();
        this.loadActiveOrder();
        this.loadOrderHistory();
        this.bindEvents();
    },

    bindEvents() {
        // File input change
        const fileInput = document.getElementById('ocr-file-input');
        if (fileInput) {
            fileInput.addEventListener('change', (e) => this.handleImageUpload(e.target.files[0]));
        }

        // Store selection change
        const storeSelect = document.getElementById('customer-store-select');
        if (storeSelect) {
            storeSelect.addEventListener('change', (e) => {
                this.selectedStoreId = parseInt(e.target.value);
                this.checkAvailabilityForSelectedStore();
            });
        }
    },

    // 1. OCR & NLP LIST EXTRACTION
    async handleImageUpload(file) {
        if (!file) return;

        const loadingOverlay = document.getElementById('ocr-loading-state');
        loadingOverlay.classList.remove('hidden');

        const formData = new FormData();
        formData.append('file', file);

        try {
            const res = await fetch('/api/customer/ocr/upload', {
                method: 'POST',
                body: formData
            });
            const data = await res.json();
            if (data.status === 'success') {
                this.renderOcrResults(data.data);
                showToast('Handwritten grocery list processed via AI!', 'success');
            } else {
                showToast('Failed to process image', 'error');
            }
        } catch (err) {
            showToast('Error during OCR processing', 'error');
        } finally {
            loadingOverlay.classList.add('hidden');
        }
    },

    async useSamplePreset(presetKey) {
        const loadingOverlay = document.getElementById('ocr-loading-state');
        loadingOverlay.classList.remove('hidden');

        const formData = new FormData();
        formData.append('preset_key', presetKey);

        try {
            const res = await fetch('/api/customer/ocr/upload', {
                method: 'POST',
                body: formData
            });
            const data = await res.json();
            if (data.status === 'success') {
                this.renderOcrResults(data.data);
                showToast(`Loaded sample list: ${presetKey.replace('_', ' ').toUpperCase()}`, 'success');
            }
        } catch (err) {
            showToast('Error loading sample list', 'error');
        } finally {
            loadingOverlay.classList.add('hidden');
        }
    },

    renderOcrResults(ocrData) {
        this.extractedItems = ocrData.items;

        // Show annotated detection image if present
        const previewImg = document.getElementById('ocr-annotated-preview');
        const imgContainer = document.getElementById('ocr-annotated-container');
        if (ocrData.annotated_image && previewImg) {
            previewImg.src = ocrData.annotated_image;
            imgContainer.classList.remove('hidden');
        }

        // Show editable table
        const tableContainer = document.getElementById('extracted-items-section');
        tableContainer.classList.remove('hidden');

        this.renderItemsTable();

        // Check availability if a store is selected
        if (this.selectedStoreId) {
            this.checkAvailabilityForSelectedStore();
        } else if (this.availableStores.length > 0) {
            this.selectedStoreId = this.availableStores[0].id;
            const selectEl = document.getElementById('customer-store-select');
            if (selectEl) selectEl.value = this.selectedStoreId;
            this.checkAvailabilityForSelectedStore();
        }

        // Smooth scroll to results
        tableContainer.scrollIntoView({ behavior: 'smooth', block: 'start' });
    },

    renderItemsTable() {
        const tbody = document.getElementById('extracted-items-tbody');
        tbody.innerHTML = '';

        this.extractedItems.forEach((item, index) => {
            const tr = document.createElement('tr');
            tr.className = 'border-b border-slate-100 hover:bg-slate-50 transition';
            tr.innerHTML = `
                <td class="py-2.5 px-3">
                    <input type="text" class="w-full text-xs font-medium text-slate-800 bg-transparent border-b border-transparent hover:border-slate-300 focus:border-emerald-500 focus:outline-none" 
                           value="${item.name}" onchange="CustomerModule.updateItemField(${index}, 'name', this.value)">
                    <span class="text-[10px] text-slate-400 block">${item.brand || 'Local Brand'} • ${item.category || 'Grocery'}</span>
                </td>
                <td class="py-2.5 px-2 text-center">
                    <input type="number" step="0.25" min="0.25" class="w-16 text-center text-xs font-semibold text-slate-800 border border-slate-200 rounded px-1 py-0.5" 
                           value="${item.quantity}" onchange="CustomerModule.updateItemField(${index}, 'quantity', parseFloat(this.value))">
                </td>
                <td class="py-2.5 px-2">
                    <select class="text-xs text-slate-700 border border-slate-200 rounded px-1 py-0.5 bg-white" 
                            onchange="CustomerModule.updateItemField(${index}, 'unit', this.value)">
                        <option value="kg" ${item.unit === 'kg' ? 'selected' : ''}>kg</option>
                        <option value="g" ${item.unit === 'g' ? 'selected' : ''}>g</option>
                        <option value="l" ${item.unit === 'l' ? 'selected' : ''}>l</option>
                        <option value="ml" ${item.unit === 'ml' ? 'selected' : ''}>ml</option>
                        <option value="packet" ${item.unit === 'packet' ? 'selected' : ''}>packet</option>
                        <option value="piece" ${item.unit === 'piece' ? 'selected' : ''}>piece</option>
                        <option value="box" ${item.unit === 'box' ? 'selected' : ''}>box</option>
                    </select>
                </td>
                <td class="py-2.5 px-2 text-right">
                    <button onclick="CustomerModule.deleteItem(${index})" class="text-rose-500 hover:text-rose-700 p-1 rounded hover:bg-rose-50" title="Remove item">
                        <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16"></path></svg>
                    </button>
                </td>
            `;
            tbody.appendChild(tr);
        });

        document.getElementById('items-count-badge').innerText = `${this.extractedItems.length} items`;
    },

    updateItemField(index, field, value) {
        if (this.extractedItems[index]) {
            this.extractedItems[index][field] = value;
            if (this.selectedStoreId) this.checkAvailabilityForSelectedStore();
        }
    },

    deleteItem(index) {
        this.extractedItems.splice(index, 1);
        this.renderItemsTable();
        if (this.selectedStoreId) this.checkAvailabilityForSelectedStore();
    },

    addNewItemRow() {
        this.extractedItems.push({
            name: "New Kirana Item",
            brand: "Standard",
            quantity: 1.0,
            unit: "packet",
            category: "General Groceries",
            confidence: 1.0
        });
        this.renderItemsTable();
        if (this.selectedStoreId) this.checkAvailabilityForSelectedStore();
    },

    // 2. STORE AVAILABILITY & PRICING (STEPS 4-5)
    async loadStores() {
        try {
            const res = await fetch('/api/stores');
            const data = await res.json();
            if (data.status === 'success') {
                this.availableStores = data.stores;
                const selectEl = document.getElementById('customer-store-select');
                if (selectEl) {
                    selectEl.innerHTML = data.stores.map(s => `
                        <option value="${s.id}">${s.name} (⭐ ${s.rating} • ${s.area})</option>
                    `).join('');
                    if (data.stores.length > 0) {
                        this.selectedStoreId = data.stores[0].id;
                    }
                }
            }
        } catch (err) {
            console.error('Error loading stores:', err);
        }
    },

    async checkAvailabilityForSelectedStore() {
        if (!this.selectedStoreId || this.extractedItems.length === 0) return;

        const payload = {
            store_id: this.selectedStoreId,
            items: this.extractedItems.map(it => ({
                name: it.name,
                quantity: it.quantity,
                unit: it.unit
            }))
        };

        try {
            const res = await fetch('/api/customer/stores/check_availability', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify(payload)
            });
            const data = await res.json();
            if (data.status === 'success') {
                this.currentAvailability = data;
                this.renderAvailabilitySummary(data);
            }
        } catch (err) {
            console.error('Error checking availability:', err);
        }
    },

    renderAvailabilitySummary(avail) {
        const container = document.getElementById('store-availability-panel');
        container.classList.remove('hidden');

        // Total bill badge
        document.getElementById('avail-total-bill').innerText = `₹${avail.total_bill}`;
        document.getElementById('avail-in-stock-count').innerText = `${avail.available_count} of ${avail.total_items_requested} items In Stock`;

        // Missing items warning banner with store switch suggestion!
        const missingBanner = document.getElementById('avail-missing-banner');
        const missingListEl = document.getElementById('avail-missing-items-list');

        if (avail.missing_count > 0) {
            missingBanner.classList.remove('hidden');
            missingListEl.innerHTML = avail.missing_items.map(m => `
                <li class="flex items-center text-rose-700 text-xs">
                    <svg class="w-3.5 h-3.5 mr-1.5 flex-shrink-0" fill="currentColor" viewBox="0 0 20 20"><path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zM8.707 7.293a1 1 0 00-1.414 1.414L8.586 10l-1.293 1.293a1 1 0 101.414 1.414L10 11.414l1.293 1.293a1 1 0 001.414-1.414L11.414 10l1.293-1.293a1 1 0 00-1.414-1.414L10 8.586 8.707 7.293z" clip-rule="evenodd"></path></svg>
                    <strong>${m.product_name}</strong> (${m.requested_quantity} ${m.unit}) - ${m.reason}
                </li>
            `).join('');
        } else {
            missingBanner.classList.add('hidden');
        }

        // Render available items breakdown
        const itemsBreakdown = document.getElementById('avail-items-breakdown');
        const deliveryFee = avail.delivery_fee !== undefined ? avail.delivery_fee : 50.0;
        const subtotal = avail.items_subtotal !== undefined ? avail.items_subtotal : (avail.total_bill - deliveryFee);
        const distKm = avail.distance_km || (avail.store && avail.store.distance_km) || 1.0;

        itemsBreakdown.innerHTML = avail.available_items.map(it => `
            <div class="flex justify-between items-center py-1.5 border-b border-slate-100 text-xs">
                <div>
                    <span class="font-medium text-slate-800">${it.product_name}</span>
                    <span class="text-slate-400 block text-[10px]">${it.requested_quantity} ${it.unit} × ₹${it.unit_price}</span>
                </div>
                <div class="font-bold text-slate-800">₹${it.subtotal}</div>
            </div>
        `).join('') + `
            <div class="flex justify-between items-center py-1.5 border-t border-slate-200 text-xs font-medium text-slate-600 mt-1">
                <span>Items Subtotal</span>
                <span>₹${subtotal.toFixed(2)}</span>
            </div>
            <div class="flex justify-between items-center py-1 text-xs">
                <span class="text-slate-600">Delivery Fee (${distKm} km @ ₹50/km)</span>
                <span class="text-amber-600 font-bold">+₹${deliveryFee.toFixed(2)}</span>
            </div>
        `;
    },

    // Switch Store helper (e.g. from missing items prompt)
    switchStore(storeId) {
        this.selectedStoreId = storeId;
        const selectEl = document.getElementById('customer-store-select');
        if (selectEl) selectEl.value = storeId;
        this.checkAvailabilityForSelectedStore();
        showToast('Switched store! Recalculating stock & pricing...', 'info');
    },

    // 3. ORDER SUBMISSION TO MERCHANT (STEPS 6-8)
    async submitOrderToMerchant() {
        if (!AppState.currentUser) {
            AuthModule.openLoginModal();
            return;
        }

        if (!this.selectedStoreId || this.extractedItems.length === 0) {
            showToast('Please upload a list and select a kirana store', 'error');
            return;
        }

        const address = AppState.currentUser.address || 'Flat 304, Palm Grove Apts, Indiranagar';
        const payload = {
            store_id: this.selectedStoreId,
            delivery_address: address,
            notes: "Please pack best available fresh batch items.",
            items: this.extractedItems
        };

        try {
            const res = await fetch(`/api/customer/orders/create?customer_id=${AppState.currentUser.id}`, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify(payload)
            });

            const data = await res.json();
            if (res.ok && data.status === 'success') {
                showToast(data.message, 'success');
                // Clear extracted table and switch to active order view
                document.getElementById('extracted-items-section').classList.add('hidden');
                document.getElementById('store-availability-panel').classList.add('hidden');
                this.loadActiveOrder();
            } else {
                showToast(data.detail || 'Failed to submit order', 'error');
            }
        } catch (err) {
            showToast('Network error while placing order', 'error');
        }
    },

    // 4. ACTIVE ORDER TRACKER & CONFIRMATION (STEPS 9-15)
    async loadActiveOrder() {
        if (!AppState.currentUser) return;
        try {
            const res = await fetch(`/api/customer/orders/active?customer_id=${AppState.currentUser.id}`);
            const data = await res.json();
            if (data.status === 'success') {
                this.activeOrder = data.order;
                this.renderActiveOrderCard(data.order);
            }
        } catch (err) {
            console.error('Error fetching active order:', err);
        }
    },

    pollActiveOrder() {
        this.loadActiveOrder();
    },

    renderActiveOrderCard(order) {
        const trackerCard = document.getElementById('customer-active-order-card');
        const emptyState = document.getElementById('customer-no-active-order');

        if (!order) {
            trackerCard.classList.add('hidden');
            emptyState.classList.remove('hidden');
            return;
        }

        emptyState.classList.add('hidden');
        trackerCard.classList.remove('hidden');

        document.getElementById('active-order-number').innerText = order.order_number;
        document.getElementById('active-order-store-name').innerText = order.store.name;
        document.getElementById('active-order-total').innerText = `₹${order.total_amount}`;
        document.getElementById('active-order-eta').innerText = `${order.estimated_delivery_minutes} mins`;

        // Render Status Stepper
        const step1 = document.getElementById('step-indicator-1'); // Sent to Merchant
        const step2 = document.getElementById('step-indicator-2'); // Packed by Merchant
        const step3 = document.getElementById('step-indicator-3'); // Out for Delivery
        const step4 = document.getElementById('step-indicator-4'); // Delivered

        this.setStepStatus(step1, true);
        this.setStepStatus(step2, order.status !== 'PENDING_MERCHANT');
        this.setStepStatus(step3, ['LOOKING_FOR_DELIVERY', 'OUT_FOR_DELIVERY', 'DELIVERED'].includes(order.status));
        this.setStepStatus(step4, order.status === 'DELIVERED');

        // Customer Confirmation Request Panel (Step 9: When merchant packs and sends confirmation)
        const confirmPanel = document.getElementById('customer-order-confirm-request-panel');
        if (order.status === 'PACKING_CONFIRMED') {
            confirmPanel.classList.remove('hidden');
            document.getElementById('confirm-request-bill').innerText = `₹${order.total_amount}`;
        } else {
            confirmPanel.classList.add('hidden');
        }

        // 6-Digit Delivery OTP Code display (CRITICAL STEP 9-10 & 11-15)
        const otpBox = document.getElementById('customer-delivery-otp-box');
        if (['LOOKING_FOR_DELIVERY', 'OUT_FOR_DELIVERY'].includes(order.status)) {
            otpBox.classList.remove('hidden');
            document.getElementById('customer-6digit-code').innerText = order.delivery_code;
        } else {
            otpBox.classList.add('hidden');
        }

        // Delivery Partner Contact card
        const partnerCard = document.getElementById('customer-delivery-partner-card');
        if (order.delivery_partner) {
            partnerCard.classList.remove('hidden');
            document.getElementById('partner-card-name').innerText = order.delivery_partner.name;
            document.getElementById('partner-card-vehicle').innerText = order.delivery_partner.vehicle;
            document.getElementById('partner-card-phone').href = `tel:${order.delivery_partner.mobile}`;
        } else {
            partnerCard.classList.add('hidden');
        }
    },

    setStepStatus(el, isComplete) {
        if (!el) return;
        if (isComplete) {
            el.className = 'w-7 h-7 rounded-full bg-emerald-500 text-white flex items-center justify-center text-xs font-bold shadow';
            el.innerHTML = '✓';
        } else {
            el.className = 'w-7 h-7 rounded-full bg-slate-200 text-slate-500 flex items-center justify-center text-xs font-medium';
            el.innerHTML = '•';
        }
    },

    // Step 9-10: Customer accepts merchant's confirmation & selects payment
    async acceptMerchantPacking(paymentMode) {
        if (!this.activeOrder) return;

        try {
            const res = await fetch(`/api/customer/orders/accept?customer_id=${AppState.currentUser.id}`, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({
                    order_id: this.activeOrder.id,
                    payment_mode: paymentMode
                })
            });

            const data = await res.json();
            if (data.status === 'success') {
                showToast(`Order Accepted! Delivery code generated: ${data.delivery_code}`, 'success');
                this.loadActiveOrder();
            }
        } catch (err) {
            showToast('Failed to accept order', 'error');
        }
    },

    async loadOrderHistory() {
        if (!AppState.currentUser) return;
        try {
            const res = await fetch(`/api/customer/orders/history?customer_id=${AppState.currentUser.id}`);
            const data = await res.json();
            if (data.status === 'success') {
                const historyList = document.getElementById('customer-order-history-list');
                if (historyList) {
                    if (data.orders.length === 0) {
                        historyList.innerHTML = `<p class="text-xs text-slate-400 py-4 text-center">No past orders yet.</p>`;
                        return;
                    }
                    historyList.innerHTML = data.orders.map(o => `
                        <div class="p-3 bg-white border border-slate-200 rounded-xl flex items-center justify-between mb-2">
                            <div>
                                <span class="font-bold text-xs text-slate-800">${o.order_number}</span>
                                <span class="text-[10px] text-slate-400 block">${o.store_name} • ${o.created_at}</span>
                                <span class="text-[10px] text-emerald-600 font-semibold">${o.status}</span>
                            </div>
                            <div class="text-right">
                                <span class="text-xs font-bold text-slate-800">₹${o.total_amount}</span>
                                <span class="text-[10px] text-slate-400 block">${o.payment_mode}</span>
                            </div>
                        </div>
                    `).join('');
                }
            }
        } catch (err) {
            console.error('Error loading history:', err);
        }
    }
};
