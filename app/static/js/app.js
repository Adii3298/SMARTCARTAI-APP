/**
 * Smart Cart AI - Main Application State & Core Navigation
 */

const AppState = {
    currentUser: null,
    currentRole: 'customer', // 'customer', 'merchant', 'delivery', 'admin'
    isPhoneMockup: false,    // toggles phone frame vs full width
    activeTab: 'home',       // role-specific active view
    pollingInterval: null
};

// Global Toast Notifications
function showToast(message, type = 'info') {
    const toast = document.getElementById('toast-notification');
    const toastMsg = document.getElementById('toast-message');
    const toastIcon = document.getElementById('toast-icon');

    if (!toast) return;

    toastMsg.innerText = message;
    toast.className = 'fixed bottom-5 right-5 z-50 flex items-center p-4 text-sm font-medium rounded-xl shadow-2xl transition-all duration-300 transform translate-y-0 opacity-100 ';

    if (type === 'success') {
        toast.className += 'bg-emerald-600 text-white';
        toastIcon.innerHTML = `<svg class="w-5 h-5 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7"></path></svg>`;
    } else if (type === 'error') {
        toast.className += 'bg-rose-600 text-white';
        toastIcon.innerHTML = `<svg class="w-5 h-5 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"></path></svg>`;
    } else {
        toast.className += 'bg-slate-800 text-white';
        toastIcon.innerHTML = `<svg class="w-5 h-5 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 16h-1v-4h-1m1-4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"></path></svg>`;
    }

    clearTimeout(window.toastTimer);
    window.toastTimer = setTimeout(() => {
        toast.className = 'hidden';
    }, 4000);
}

// Simulated SMS Modal
function showSmsCredentialsModal(smsText, credentials) {
    const modal = document.getElementById('sms-notification-modal');
    const smsContent = document.getElementById('sms-notification-text');
    const copyIdBtn = document.getElementById('sms-copy-id-btn');
    const quickLoginBtn = document.getElementById('sms-quick-login-btn');

    if (!modal) return;

    smsContent.innerText = smsText;
    modal.classList.remove('hidden');
    modal.classList.add('flex');

    copyIdBtn.onclick = () => {
        navigator.clipboard.writeText(credentials.user_id);
        showToast(`Copied User ID: ${credentials.user_id}`, 'success');
    };

    quickLoginBtn.onclick = () => {
        modal.classList.add('hidden');
        modal.classList.remove('flex');
        // Auto-fill login form
        document.getElementById('login-id-input').value = credentials.user_id;
        document.getElementById('login-password-input').value = credentials.password;
        document.getElementById('login-modal').classList.remove('hidden');
        document.getElementById('login-modal').classList.add('flex');
        AuthModule.refreshCaptcha();
        showToast('Credentials filled! Solve the CAPTCHA to enter.', 'info');
    };
}

function closeSmsModal() {
    const modal = document.getElementById('sms-notification-modal');
    if (modal) {
        modal.classList.add('hidden');
        modal.classList.remove('flex');
    }
}

// Toggle Phone Mockup frame vs Wide screen
function toggleDeviceView() {
    AppState.isPhoneMockup = !AppState.isPhoneMockup;
    const container = document.getElementById('main-viewport-container');
    const toggleBtn = document.getElementById('view-mode-toggle-btn');
    const notch = document.getElementById('phone-notch');

    if (AppState.isPhoneMockup) {
        container.classList.remove('desktop-view-wrapper');
        container.classList.add('phone-mockup-wrapper');
        notch.classList.remove('hidden');
        toggleBtn.innerHTML = `
            <svg class="w-4 h-4 mr-1.5" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9.75 17L9 20l-1 1h8l-1-1-.75-3M3 13h18M5 17h14a2 2 0 002-2V5a2 2 0 00-2-2H5a2 2 0 00-2 2v10a2 2 0 002 2z"></path></svg>
            Switch to Desktop View
        `;
    } else {
        container.classList.add('desktop-view-wrapper');
        container.classList.remove('phone-mockup-wrapper');
        notch.classList.add('hidden');
        toggleBtn.innerHTML = `
            <svg class="w-4 h-4 mr-1.5" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 18h.01M8 21h8a2 2 0 002-2V5a2 2 0 00-2-2H8a2 2 0 00-2 2v14a2 2 0 002 2z"></path></svg>
            Switch to Mobile Frame
        `;
    }
}

// 1-Click Quick Demo Login Switch
async function quickSwitchDemoRole(role) {
    try {
        const res = await fetch(`/api/auth/quick_switch?role=${role}`, { method: 'POST' });
        const data = await res.json();
        if (data.status === 'success') {
            AppState.currentUser = data.user;
            AppState.currentRole = data.user.role;
            updateAppView();
            showToast(`Logged in as ${data.user.name} (${data.user.role.toUpperCase()})`, 'success');
        } else {
            showToast(data.detail || 'Failed to switch role', 'error');
        }
    } catch (e) {
        showToast('Network error during quick switch', 'error');
    }
}

// Update App View according to logged-in user role
function updateAppView() {
    // Update active portal badge
    const activeBadge = document.getElementById('active-portal-title');
    if (activeBadge) {
        const labels = {
            'customer': '🛒 Customer App',
            'merchant': '🏪 Kirana Merchant Portal',
            'delivery': '🛵 Delivery Fleet Portal',
            'admin': '⚡ Admin Command Center'
        };
        activeBadge.innerText = labels[AppState.currentRole] || `${AppState.currentRole.toUpperCase()} Portal`;
    }

    // Update logged in user badge
    const userBadgeName = document.getElementById('nav-user-name');
    const userBadgeRole = document.getElementById('nav-user-role');
    if (AppState.currentUser) {
        userBadgeName.innerText = AppState.currentUser.name;
        userBadgeRole.innerText = AppState.currentUser.role.toUpperCase();
    }

    // Hide all role dashboard containers
    document.getElementById('customer-dashboard').classList.add('hidden');
    document.getElementById('merchant-dashboard').classList.add('hidden');
    document.getElementById('delivery-dashboard').classList.add('hidden');
    document.getElementById('admin-dashboard').classList.add('hidden');

    // Show appropriate role dashboard
    if (AppState.currentRole === 'customer') {
        document.getElementById('customer-dashboard').classList.remove('hidden');
        CustomerModule.init();
    } else if (AppState.currentRole === 'merchant') {
        document.getElementById('merchant-dashboard').classList.remove('hidden');
        MerchantModule.init();
    } else if (AppState.currentRole === 'delivery') {
        document.getElementById('delivery-dashboard').classList.remove('hidden');
        DeliveryModule.init();
    } else if (AppState.currentRole === 'admin') {
        document.getElementById('admin-dashboard').classList.remove('hidden');
        AdminModule.init();
    }
}

// Real-time synchronization loop: refreshes active order state every 4 seconds
function startBackgroundSync() {
    if (AppState.pollingInterval) clearInterval(AppState.pollingInterval);
    AppState.pollingInterval = setInterval(() => {
        if (!AppState.currentUser) return;
        if (AppState.currentRole === 'customer') {
            CustomerModule.pollActiveOrder();
        } else if (AppState.currentRole === 'merchant') {
            MerchantModule.pollOrders();
        } else if (AppState.currentRole === 'delivery') {
            DeliveryModule.pollDeliveries();
        }
    }, 4000);
}

// DOM Initialization
document.addEventListener('DOMContentLoaded', () => {
    // Quick login by default to Customer role for immediate interactive experience
    quickSwitchDemoRole('customer');
    startBackgroundSync();
});
