/**
 * Smart Cart AI - Merchant Dashboard & Inventory Manager Module
 */

const MerchantModule = {
    orders: [],
    inventory: [],
    activeTab: 'orders', // 'orders' or 'inventory'
    activeOrderFilter: 'all',

    init() {
        this.loadOrders();
        this.loadInventory();
        this.bindEvents();
    },

    bindEvents() {
        // Search & category filters
        const searchInput = document.getElementById('merchant-inv-search');
        if (searchInput) {
            searchInput.addEventListener('input', (e) => this.filterInventory(e.target.value));
        }

        const catSelect = document.getElementById('merchant-inv-category-select');
        if (catSelect) {
            catSelect.addEventListener('change', (e) => this.loadInventory(e.target.value));
        }

        // Add Product Form
        const addProductForm = document.getElementById('merchant-add-product-form');
        if (addProductForm) {
            addProductForm.addEventListener('submit', (e) => this.handleAddProduct(e));
        }
    },

    switchSubTab(tab) {
        this.activeTab = tab;
        const ordersView = document.getElementById('merchant-orders-view');
        const invView = document.getElementById('merchant-inventory-view');
        const ordersTabBtn = document.getElementById('merchant-tab-orders-btn');
        const invTabBtn = document.getElementById('merchant-tab-inv-btn');

        if (tab === 'orders') {
            ordersView.classList.remove('hidden');
            invView.classList.add('hidden');
            ordersTabBtn.className = 'px-4 py-2 text-xs font-bold rounded-lg bg-emerald-600 text-white shadow-sm';
            invTabBtn.className = 'px-4 py-2 text-xs font-medium rounded-lg text-slate-600 hover:bg-slate-100';
            this.loadOrders();
        } else {
            ordersView.classList.add('hidden');
            invView.classList.remove('hidden');
            invTabBtn.className = 'px-4 py-2 text-xs font-bold rounded-lg bg-emerald-600 text-white shadow-sm';
            ordersTabBtn.className = 'px-4 py-2 text-xs font-medium rounded-lg text-slate-600 hover:bg-slate-100';
            this.loadInventory();
        }
    },

    // 1. ORDERS WORKFLOW & PACKING (STEPS 6-8)
    async loadOrders(dateFilter = null) {
        if (!AppState.currentUser) return;
        try {
            let url = `/api/merchant/orders?merchant_id=${AppState.currentUser.id}`;
            if (dateFilter) url += `&date_filter=${dateFilter}`;

            const res = await fetch(url);
            const data = await res.json();
            if (data.status === 'success') {
                this.orders = data.orders;
                this.renderOrders();
            }
        } catch (err) {
            console.error('Error loading merchant orders:', err);
        }
    },

    pollOrders() {
        if (this.activeTab === 'orders') {
            this.loadOrders();
        }
    },

    filterOrdersByStatus(status) {
        this.activeOrderFilter = status;
        this.renderOrders();
    },

    renderOrders() {
        const container = document.getElementById('merchant-orders-list');
        if (!container) return;

        let filtered = this.orders;
        if (this.activeOrderFilter !== 'all') {
            filtered = this.orders.filter(o => o.status === this.activeOrderFilter);
        }

        if (filtered.length === 0) {
            container.innerHTML = `<div class="p-8 text-center text-slate-400 text-xs">No orders in this view.</div>`;
            return;
        }

        container.innerHTML = filtered.map(order => {
            const isPendingPack = order.status === 'PENDING_MERCHANT';
            const statusColor = isPendingPack ? 'bg-amber-100 text-amber-800' :
                order.status === 'PACKING_CONFIRMED' ? 'bg-blue-100 text-blue-800' :
                order.status === 'OUT_FOR_DELIVERY' ? 'bg-purple-100 text-purple-800' :
                order.status === 'DELIVERED' ? 'bg-emerald-100 text-emerald-800' : 'bg-slate-100 text-slate-800';

            return `
                <div class="bg-white border border-slate-200 rounded-2xl p-4 shadow-sm mb-4">
                    <div class="flex justify-between items-start mb-3">
                        <div>
                            <span class="font-bold text-sm text-slate-800">${order.order_number}</span>
                            <span class="text-xs text-slate-500 block">${order.customer_name} • 📞 ${order.customer_phone}</span>
                            <span class="text-[11px] text-slate-400 block">${order.customer_address}</span>
                        </div>
                        <div class="text-right">
                            <span class="px-2.5 py-1 rounded-full text-[10px] font-bold ${statusColor}">
                                ${order.status.replace(/_/g, ' ')}
                            </span>
                            <span class="text-xs font-black text-slate-900 block mt-1">₹${order.total_amount}</span>
                        </div>
                    </div>

                    <!-- Items Checklist / Packing table -->
                    <div class="bg-slate-50 rounded-xl p-3 mb-3 border border-slate-100">
                        <div class="text-[11px] font-semibold text-slate-600 mb-2 flex justify-between">
                            <span>Requested Grocery Items (${order.items.length})</span>
                            <span>${order.created_at}</span>
                        </div>
                        <div class="space-y-2">
                            ${order.items.map((it, idx) => `
                                <div class="flex items-center justify-between text-xs py-1 border-b border-slate-200/50">
                                    <div class="flex items-center space-x-2">
                                        <input type="checkbox" id="item-chk-${order.id}-${it.id}" 
                                               ${it.is_available ? 'checked' : ''} 
                                               ${!isPendingPack ? 'disabled' : ''}
                                               class="rounded text-emerald-600 w-4 h-4 focus:ring-emerald-500">
                                        <div>
                                            <span class="font-medium text-slate-800">${it.product_name}</span>
                                            <span class="text-[10px] text-slate-400 block">Req: ${it.requested_quantity} ${it.unit}</span>
                                        </div>
                                    </div>
                                    <div class="flex items-center space-x-2">
                                        ${isPendingPack ? `
                                            <span class="text-[10px] text-slate-500">Qty:</span>
                                            <input type="number" step="0.25" min="0" value="${it.packed_quantity}" 
                                                   id="item-qty-${order.id}-${it.id}" 
                                                   class="w-14 text-center border border-slate-200 rounded px-1 py-0.5 text-xs font-semibold">
                                            <span class="text-[10px] text-slate-500">₹</span>
                                            <input type="number" step="1" min="0" value="${it.unit_price}" 
                                                   id="item-price-${order.id}-${it.id}" 
                                                   class="w-14 text-center border border-slate-200 rounded px-1 py-0.5 text-xs font-semibold">
                                        ` : `
                                            <span class="font-semibold text-slate-700">${it.packed_quantity} ${it.unit}</span>
                                            <span class="font-bold text-slate-800">₹${it.subtotal}</span>
                                        `}
                                    </div>
                                </div>
                            `).join('')}
                        </div>
                    </div>

                    ${isPendingPack ? `
                        <div class="flex space-x-2">
                            <button onclick="MerchantModule.confirmPackingAndBill(${order.id})" 
                                    class="flex-1 bg-emerald-600 hover:bg-emerald-700 text-white font-bold py-2.5 px-4 rounded-xl text-xs flex items-center justify-center shadow">
                                <svg class="w-4 h-4 mr-1.5" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7"></path></svg>
                                Pack & Send Confirmation to Customer
                            </button>
                        </div>
                    ` : `
                        <div class="flex items-center justify-between text-[11px] text-slate-500 pt-1">
                            <span>Delivery Partner: <strong>${order.delivery_partner_name}</strong></span>
                            <span>Payment: <strong>${order.payment_mode}</strong></span>
                        </div>
                    `}
                </div>
            `;
        }).join('');
    },

    // Step 6-8: Pack items, calculate bill, and dispatch confirmation request to customer
    async confirmPackingAndBill(orderId) {
        const order = this.orders.find(o => o.id === orderId);
        if (!order) return;

        let total = 0.0;
        const packedItems = order.items.map(it => {
            const chkEl = document.getElementById(`item-chk-${orderId}-${it.id}`);
            const qtyEl = document.getElementById(`item-qty-${orderId}-${it.id}`);
            const priceEl = document.getElementById(`item-price-${orderId}-${it.id}`);

            const isAvail = chkEl ? chkEl.checked : true;
            const packedQty = qtyEl ? parseFloat(qtyEl.value) : it.requested_quantity;
            const unitPrice = priceEl ? parseFloat(priceEl.value) : it.unit_price;

            if (isAvail) {
                total += (packedQty * unitPrice);
            }

            return {
                item_id: it.id,
                packed_quantity: packedQty,
                unit_price: unitPrice,
                is_available: isAvail
            };
        });

        try {
            const res = await fetch(`/api/merchant/orders/pack_and_confirm?merchant_id=${AppState.currentUser.id}`, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({
                    order_id: orderId,
                    items: packedItems,
                    total_amount: total,
                    notes: "Packed fresh from local kirana."
                })
            });

            const data = await res.json();
            if (data.status === 'success') {
                showToast(`Order packed! Total bill ₹${total} sent to customer for acceptance.`, 'success');
                this.loadOrders();
            }
        } catch (err) {
            showToast('Failed to confirm packing', 'error');
        }
    },

    // 2. REAL-TIME INVENTORY & BRAND MANAGER
    async loadInventory(category = null) {
        if (!AppState.currentUser) return;
        try {
            let url = `/api/merchant/inventory?merchant_id=${AppState.currentUser.id}`;
            if (category) url += `&category=${category}`;

            const res = await fetch(url);
            const data = await res.json();
            if (data.status === 'success') {
                this.inventory = data.inventory;
                this.renderInventoryTable(data.inventory);
            }
        } catch (err) {
            console.error('Error loading inventory:', err);
        }
    },

    renderInventoryTable(items) {
        const tbody = document.getElementById('merchant-inv-tbody');
        if (!tbody) return;

        tbody.innerHTML = items.map(item => `
            <tr class="border-b border-slate-100 hover:bg-slate-50 transition text-xs">
                <td class="py-2.5 px-3">
                    <span class="font-bold text-slate-800 block">${item.name}</span>
                    <span class="text-[10px] text-slate-400">${item.brand || 'Local Brand'} • ${item.category}</span>
                </td>
                <td class="py-2.5 px-2 text-center">
                    <div class="flex items-center justify-center space-x-1">
                        <span class="text-slate-400">₹</span>
                        <input type="number" step="1" value="${item.price}" 
                               class="w-16 text-center border border-slate-200 rounded px-1 py-0.5 font-bold text-slate-800"
                               onchange="MerchantModule.updateItemPrice(${item.id}, this.value)">
                    </div>
                </td>
                <td class="py-2.5 px-2 text-center">
                    <input type="number" step="1" value="${item.stock_quantity}" 
                           class="w-16 text-center border border-slate-200 rounded px-1 py-0.5 font-medium text-slate-700"
                           onchange="MerchantModule.updateItemStock(${item.id}, this.value)">
                    <span class="text-[10px] text-slate-400 block">${item.unit}</span>
                </td>
                <td class="py-2.5 px-2 text-center">
                    <label class="relative inline-flex items-center cursor-pointer">
                        <input type="checkbox" ${item.is_in_stock ? 'checked' : ''} 
                               class="sr-only peer" 
                               onchange="MerchantModule.toggleStockStatus(${item.id}, this.checked)">
                        <div class="w-9 h-5 bg-slate-200 peer-focus:outline-none rounded-full peer peer-checked:after:translate-x-full peer-checked:after:border-white after:content-[''] after:absolute after:top-[2px] after:left-[2px] after:bg-white after:border-gray-300 after:border after:rounded-full after:h-4 after:w-4 after:transition-all peer-checked:bg-emerald-500"></div>
                    </label>
                    <span class="text-[9px] block ${item.is_in_stock ? 'text-emerald-600 font-bold' : 'text-rose-500 font-bold'}">
                        ${item.is_in_stock ? 'IN STOCK' : 'OUT OF STOCK'}
                    </span>
                </td>
                <td class="py-2.5 px-2 text-right">
                    <button onclick="MerchantModule.deleteProduct(${item.id})" class="text-rose-500 hover:text-rose-700 p-1 rounded hover:bg-rose-50">
                        <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16"></path></svg>
                    </button>
                </td>
            </tr>
        `).join('');

        document.getElementById('merchant-total-products-count').innerText = `${items.length} Products`;
    },

    filterInventory(query) {
        const q = query.toLowerCase().trim();
        const filtered = this.inventory.filter(it => 
            it.name.toLowerCase().includes(q) || (it.brand && it.brand.toLowerCase().includes(q))
        );
        this.renderInventoryTable(filtered);
    },

    async updateItemPrice(itemId, newPrice) {
        try {
            await fetch(`/api/merchant/inventory/${itemId}?merchant_id=${AppState.currentUser.id}`, {
                method: 'PUT',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ price: parseFloat(newPrice) })
            });
            showToast('Price updated in real-time!', 'success');
        } catch (err) {
            showToast('Failed to update price', 'error');
        }
    },

    async updateItemStock(itemId, newStock) {
        try {
            await fetch(`/api/merchant/inventory/${itemId}?merchant_id=${AppState.currentUser.id}`, {
                method: 'PUT',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ stock_quantity: parseFloat(newStock) })
            });
            showToast('Stock quantity updated!', 'success');
        } catch (err) {
            showToast('Failed to update stock', 'error');
        }
    },

    async toggleStockStatus(itemId, isInStock) {
        try {
            await fetch(`/api/merchant/inventory/${itemId}?merchant_id=${AppState.currentUser.id}`, {
                method: 'PUT',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ is_in_stock: isInStock })
            });
            showToast(isInStock ? 'Marked as IN STOCK' : 'Marked as OUT OF STOCK', 'info');
            this.loadInventory();
        } catch (err) {
            showToast('Failed to toggle stock status', 'error');
        }
    },

    async deleteProduct(itemId) {
        if (!confirm('Remove this product from your store inventory?')) return;
        try {
            await fetch(`/api/merchant/inventory/${itemId}?merchant_id=${AppState.currentUser.id}`, {
                method: 'DELETE'
            });
            showToast('Product removed', 'info');
            this.loadInventory();
        } catch (err) {
            showToast('Failed to remove product', 'error');
        }
    },

    openAddProductModal() {
        document.getElementById('merchant-add-product-modal').classList.remove('hidden');
        document.getElementById('merchant-add-product-modal').classList.add('flex');
    },

    closeAddProductModal() {
        document.getElementById('merchant-add-product-modal').classList.add('hidden');
        document.getElementById('merchant-add-product-modal').classList.remove('flex');
    },

    async handleAddProduct(e) {
        e.preventDefault();
        const payload = {
            name: document.getElementById('new-prod-name').value.trim(),
            brand: document.getElementById('new-prod-brand').value.trim() || 'Standard',
            category: document.getElementById('new-prod-cat').value,
            unit: document.getElementById('new-prod-unit').value,
            price: parseFloat(document.getElementById('new-prod-price').value),
            stock_quantity: parseFloat(document.getElementById('new-prod-stock').value),
            is_in_stock: true
        };

        try {
            const res = await fetch(`/api/merchant/inventory?merchant_id=${AppState.currentUser.id}`, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify(payload)
            });
            const data = await res.json();
            if (data.status === 'success') {
                showToast(data.message, 'success');
                this.closeAddProductModal();
                this.loadInventory();
            }
        } catch (err) {
            showToast('Failed to add product', 'error');
        }
    }
};
