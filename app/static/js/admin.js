/**
 * Smart Cart AI - Admin Dashboard Module
 * Platform Analytics, Smart Cart Nodes, User Management, Activity Logs
 */

const AdminModule = {
    analytics: null,
    users: [],
    nodes: [],
    logs: [],
    activeTab: 'analytics', // 'analytics', 'users', 'nodes', 'logs'

    init() {
        this.loadAnalytics();
        this.loadUsers();
        this.loadNodes();
        this.loadLogs();
        this.bindEvents();
    },

    bindEvents() {
        const userRoleFilter = document.getElementById('admin-user-role-filter');
        if (userRoleFilter) {
            userRoleFilter.addEventListener('change', (e) => this.loadUsers(e.target.value));
        }

        const addNodeForm = document.getElementById('admin-add-node-form');
        if (addNodeForm) {
            addNodeForm.addEventListener('submit', (e) => this.handleCreateNode(e));
        }
    },

    switchSubTab(tab) {
        this.activeTab = tab;
        ['analytics', 'users', 'nodes', 'logs'].forEach(t => {
            const view = document.getElementById(`admin-${t}-view`);
            const btn = document.getElementById(`admin-tab-${t}-btn`);
            if (view) {
                if (t === tab) {
                    view.classList.remove('hidden');
                    btn.className = 'px-3 py-1.5 text-xs font-bold rounded-lg bg-emerald-600 text-white shadow-sm';
                } else {
                    view.classList.add('hidden');
                    btn.className = 'px-3 py-1.5 text-xs font-medium rounded-lg text-slate-600 hover:bg-slate-100';
                }
            }
        });
    },

    async loadAnalytics() {
        try {
            const res = await fetch('/api/admin/analytics');
            const data = await res.json();
            if (data.status === 'success') {
                this.analytics = data.analytics;
                document.getElementById('admin-gmv-stat').innerText = `₹${data.analytics.total_gmv}`;
                document.getElementById('admin-orders-stat').innerText = data.analytics.total_orders;
                document.getElementById('admin-stores-stat').innerText = data.analytics.stores_count;
                document.getElementById('admin-delivery-stat').innerText = data.analytics.delivery_count;
                document.getElementById('admin-cust-stat').innerText = data.analytics.customers_count;
                document.getElementById('admin-nodes-stat').innerText = data.analytics.nodes_count;
            }
        } catch (err) {
            console.error('Error loading analytics:', err);
        }
    },

    async loadUsers(role = 'all') {
        try {
            const res = await fetch(`/api/admin/users?role=${role}`);
            const data = await res.json();
            if (data.status === 'success') {
                this.users = data.users;
                this.renderUsersTable(data.users);
            }
        } catch (err) {
            console.error('Error loading users:', err);
        }
    },

    renderUsersTable(users) {
        const tbody = document.getElementById('admin-users-tbody');
        if (!tbody) return;

        tbody.innerHTML = users.map(u => {
            const roleColor = u.role === 'admin' ? 'bg-purple-100 text-purple-800' :
                u.role === 'merchant' ? 'bg-blue-100 text-blue-800' :
                u.role === 'delivery' ? 'bg-amber-100 text-amber-800' : 'bg-emerald-100 text-emerald-800';

            return `
                <tr class="border-b border-slate-100 hover:bg-slate-50 transition text-xs">
                    <td class="py-2.5 px-3">
                        <span class="font-bold text-slate-800 block">${u.name}</span>
                        <span class="text-[10px] text-slate-400 font-mono">${u.user_id}</span>
                    </td>
                    <td class="py-2.5 px-2">
                        <span class="px-2 py-0.5 rounded-full text-[10px] font-bold ${roleColor}">
                            ${u.role.toUpperCase()}
                        </span>
                    </td>
                    <td class="py-2.5 px-2 text-slate-600 font-mono text-[11px]">${u.mobile}</td>
                    <td class="py-2.5 px-2 text-slate-500">${u.area || 'Indiranagar'}</td>
                    <td class="py-2.5 px-2 text-center">
                        <button onclick="AdminModule.toggleUserStatus(${u.id})" 
                                class="px-2.5 py-1 rounded-full text-[10px] font-bold ${u.is_active ? 'bg-emerald-50 text-emerald-700 border border-emerald-200' : 'bg-rose-50 text-rose-700 border border-rose-200'}">
                            ${u.is_active ? 'Active' : 'Deactivated'}
                        </button>
                    </td>
                </tr>
            `;
        }).join('');
    },

    async toggleUserStatus(userId) {
        try {
            const res = await fetch(`/api/admin/users/${userId}/toggle_status`, { method: 'PUT' });
            const data = await res.json();
            if (data.status === 'success') {
                showToast(`User status updated to ${data.is_active ? 'Active' : 'Deactivated'}`, 'info');
                this.loadUsers();
            }
        } catch (err) {
            showToast('Failed to toggle status', 'error');
        }
    },

    async loadNodes() {
        try {
            const res = await fetch('/api/admin/nodes');
            const data = await res.json();
            if (data.status === 'success') {
                this.nodes = data.nodes;
                const container = document.getElementById('admin-nodes-list');
                if (container) {
                    container.innerHTML = data.nodes.map(n => `
                        <div class="bg-white border border-slate-200 rounded-xl p-3.5 mb-2.5 shadow-sm flex justify-between items-center text-xs">
                            <div>
                                <div class="flex items-center space-x-2">
                                    <span class="font-bold text-slate-800">${n.name}</span>
                                    <span class="font-mono text-[10px] bg-slate-100 text-slate-600 px-1.5 py-0.5 rounded">${n.node_code}</span>
                                </div>
                                <span class="text-[10px] text-slate-400 block">${n.area}, ${n.city} • PIN: ${n.pincode}</span>
                            </div>
                            <div class="text-right">
                                <span class="text-[10px] font-bold text-emerald-600 bg-emerald-50 px-2 py-0.5 rounded-full border border-emerald-100">
                                    ${n.status.toUpperCase()}
                                </span>
                                <span class="text-[10px] text-slate-400 block mt-1">${n.stores_count} connected stores</span>
                            </div>
                        </div>
                    `).join('');
                }
            }
        } catch (err) {
            console.error('Error loading nodes:', err);
        }
    },

    openAddNodeModal() {
        document.getElementById('admin-add-node-modal').classList.remove('hidden');
        document.getElementById('admin-add-node-modal').classList.add('flex');
    },

    closeAddNodeModal() {
        document.getElementById('admin-add-node-modal').classList.add('hidden');
        document.getElementById('admin-add-node-modal').classList.remove('flex');
    },

    async handleCreateNode(e) {
        e.preventDefault();
        const payload = {
            node_code: document.getElementById('new-node-code').value.trim(),
            name: document.getElementById('new-node-name').value.trim(),
            area: document.getElementById('new-node-area').value.trim(),
            city: "Bengaluru",
            pincode: document.getElementById('new-node-pincode').value.trim()
        };

        try {
            const res = await fetch('/api/admin/nodes', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify(payload)
            });
            const data = await res.json();
            if (data.status === 'success') {
                showToast(`Smart Cart Node ${payload.node_code} created!`, 'success');
                this.closeAddNodeModal();
                this.loadNodes();
            }
        } catch (err) {
            showToast('Failed to create node', 'error');
        }
    },

    async loadLogs() {
        try {
            const res = await fetch('/api/admin/activity_logs');
            const data = await res.json();
            if (data.status === 'success') {
                this.logs = data.logs;
                const container = document.getElementById('admin-logs-list');
                if (container) {
                    container.innerHTML = data.logs.map(l => `
                        <div class="py-2 border-b border-slate-100 text-xs flex items-start space-x-2">
                            <span class="w-1.5 h-1.5 rounded-full bg-emerald-500 mt-1.5 flex-shrink-0"></span>
                            <div class="flex-1">
                                <div class="flex justify-between items-center">
                                    <span class="font-bold text-slate-700">${l.action}</span>
                                    <span class="text-[10px] text-slate-400">${l.time}</span>
                                </div>
                                <p class="text-[11px] text-slate-500">${l.details}</p>
                            </div>
                        </div>
                    `).join('');
                }
            }
        } catch (err) {
            console.error('Error loading logs:', err);
        }
    }
};
