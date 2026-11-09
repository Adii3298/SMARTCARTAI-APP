/**
 * Smart Cart AI - Delivery Partner Module
 * Implements Gigs acceptance, Active Routing, and 6-Digit OTP Code Verification
 */

const DeliveryModule = {
    activeOrder: null,
    availableGigs: [],

    init() {
        this.loadDeliveries();
        this.loadHistory();
    },

    async loadDeliveries() {
        if (!AppState.currentUser) return;
        try {
            const res = await fetch(`/api/delivery/available_orders?delivery_id=${AppState.currentUser.id}`);
            const data = await res.json();
            if (data.status === 'success') {
                this.activeOrder = data.active_order;
                this.availableGigs = data.available_gigs;
                this.renderDeliveryView();
            }
        } catch (err) {
            console.error('Error fetching deliveries:', err);
        }
    },

    pollDeliveries() {
        this.loadDeliveries();
    },

    renderDeliveryView() {
        const activeContainer = document.getElementById('delivery-active-gig-container');
        const availableContainer = document.getElementById('delivery-available-gigs-container');
        const emptyState = document.getElementById('delivery-no-gigs-msg');

        // Active delivery assigned to this partner
        if (this.activeOrder) {
            activeContainer.classList.remove('hidden');
            document.getElementById('active-gig-order-num').innerText = this.activeOrder.order_number;
            document.getElementById('active-gig-store-name').innerText = this.activeOrder.store_name;
            document.getElementById('active-gig-store-addr').innerText = this.activeOrder.store_address;
            document.getElementById('active-gig-cust-name').innerText = this.activeOrder.customer_name;
            document.getElementById('active-gig-cust-addr').innerText = this.activeOrder.customer_address;
            document.getElementById('active-gig-cust-phone').href = `tel:${this.activeOrder.customer_phone}`;
            document.getElementById('active-gig-amount').innerText = `₹${this.activeOrder.total_amount}`;
            document.getElementById('active-gig-paymode').innerText = this.activeOrder.payment_mode;
        } else {
            activeContainer.classList.add('hidden');
        }

        // Available gigs waiting for pickup
        if (this.availableGigs.length > 0) {
            emptyState.classList.add('hidden');
            availableContainer.innerHTML = this.availableGigs.map(gig => `
                <div class="bg-white border border-slate-200 rounded-2xl p-4 shadow-sm mb-3">
                    <div class="flex justify-between items-start mb-2">
                        <div>
                            <span class="font-bold text-sm text-slate-800">${gig.order_number}</span>
                            <span class="text-xs text-emerald-600 font-semibold block">${gig.store_name}</span>
                        </div>
                        <div class="text-right">
                            <span class="text-xs font-black text-emerald-700 bg-emerald-50 px-2 py-0.5 rounded-full border border-emerald-200">
                                +₹${gig.delivery_fee} Fee
                            </span>
                        </div>
                    </div>

                    <div class="space-y-1 text-xs text-slate-600 mb-3 bg-slate-50 p-2.5 rounded-xl border border-slate-100">
                        <div class="flex items-center text-[11px]">
                            <span class="w-16 text-slate-400">Pickup:</span>
                            <span class="font-medium text-slate-700 truncate">${gig.store_address}</span>
                        </div>
                        <div class="flex items-center text-[11px]">
                            <span class="w-16 text-slate-400">Drop:</span>
                            <span class="font-medium text-slate-700 truncate">${gig.customer_address}</span>
                        </div>
                        <div class="flex items-center justify-between text-[11px] pt-1">
                            <span class="text-slate-400">Distance: <strong>~${gig.distance_km} km</strong></span>
                            <span class="text-slate-400">Order: <strong>₹${gig.total_amount} (${gig.payment_mode})</strong></span>
                        </div>
                    </div>

                    <div class="flex space-x-2">
                        <button onclick="DeliveryModule.acceptGig(${gig.id})" 
                                class="flex-1 bg-emerald-600 hover:bg-emerald-700 text-white font-bold py-2 px-3 rounded-xl text-xs flex items-center justify-center shadow">
                            <svg class="w-4 h-4 mr-1" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7"></path></svg>
                            Accept Gig
                        </button>
                        <button onclick="DeliveryModule.rejectGig(${gig.id})" 
                                class="px-3 py-2 bg-slate-100 hover:bg-slate-200 text-slate-600 font-medium rounded-xl text-xs">
                            Pass
                        </button>
                    </div>
                </div>
            `).join('');
        } else {
            availableContainer.innerHTML = '';
            if (!this.activeOrder) emptyState.classList.remove('hidden');
        }
    },

    async acceptGig(orderId) {
        if (!AppState.currentUser) return;
        try {
            const res = await fetch(`/api/delivery/orders/accept?delivery_id=${AppState.currentUser.id}`, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ order_id: orderId })
            });
            const data = await res.json();
            if (data.status === 'success') {
                showToast(data.message, 'success');
                this.loadDeliveries();
            } else {
                showToast(data.detail || 'Could not accept order', 'error');
            }
        } catch (err) {
            showToast('Error accepting delivery gig', 'error');
        }
    },

    rejectGig(orderId) {
        this.availableGigs = this.availableGigs.filter(g => g.id !== orderId);
        this.renderDeliveryView();
        showToast('Gig skipped', 'info');
    },

    // Step 11-15 (Delivery & Verification): Enter customer's 6-digit OTP code
    openVerificationModal() {
        if (!this.activeOrder) return;
        document.getElementById('delivery-otp-input').value = '';
        const modal = document.getElementById('delivery-verify-modal');
        modal.classList.remove('hidden');
        modal.classList.add('flex');
    },

    closeVerificationModal() {
        const modal = document.getElementById('delivery-verify-modal');
        modal.classList.add('hidden');
        modal.classList.remove('flex');
    },

    async verifyDeliveryCode() {
        if (!this.activeOrder) return;
        const codeInput = document.getElementById('delivery-otp-input');
        const code = codeInput.value.trim();

        if (code.length !== 6) {
            showToast('Please enter the full 6-digit delivery code', 'error');
            return;
        }

        try {
            const res = await fetch(`/api/delivery/orders/verify_and_complete?delivery_id=${AppState.currentUser.id}`, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({
                    order_id: this.activeOrder.id,
                    delivery_code: code
                })
            });

            const data = await res.json();
            if (res.ok && data.status === 'success') {
                this.closeVerificationModal();
                showToast(data.message, 'success');
                this.loadDeliveries();
                this.loadHistory();
            } else {
                showToast(data.detail || 'Code verification failed. Check OTP.', 'error');
            }
        } catch (err) {
            showToast('Network error during OTP verification', 'error');
        }
    },

    async loadHistory() {
        if (!AppState.currentUser) return;
        try {
            const res = await fetch(`/api/delivery/orders/history?delivery_id=${AppState.currentUser.id}`);
            const data = await res.json();
            if (data.status === 'success') {
                document.getElementById('delivery-earnings-badge').innerText = `₹${data.total_earnings}`;
                document.getElementById('delivery-completed-count').innerText = `${data.total_completed} Completed`;

                const historyContainer = document.getElementById('delivery-history-list');
                if (historyContainer) {
                    if (data.deliveries.length === 0) {
                        historyContainer.innerHTML = `<div class="p-4 text-center text-xs text-slate-400">No completed deliveries yet.</div>`;
                        return;
                    }
                    historyContainer.innerHTML = data.deliveries.map(d => `
                        <div class="p-3 bg-white border border-slate-100 rounded-xl mb-2 flex justify-between items-center text-xs">
                            <div>
                                <span class="font-bold text-slate-800">${d.order_number}</span>
                                <span class="text-[10px] text-slate-400 block">${d.store_name} ➔ ${d.customer_name}</span>
                                <span class="text-[9px] text-emerald-600 font-semibold">${d.delivered_at}</span>
                            </div>
                            <div class="text-right">
                                <span class="font-black text-emerald-700 text-xs">+₹${d.delivery_fee}</span>
                                <span class="text-[9px] text-slate-400 block">${d.payment_mode}</span>
                            </div>
                        </div>
                    `).join('');
                }
            }
        } catch (err) {
            console.error('Error loading delivery history:', err);
        }
    }
};
