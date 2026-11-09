/**
 * Smart Cart AI - Authentication & Interactive CAPTCHA Module
 */

const AuthModule = {
    currentCaptchaId: null,

    init() {
        this.bindEvents();
    },

    bindEvents() {
        // Register role selector change
        const regRoleSelect = document.getElementById('reg-role-select');
        if (regRoleSelect) {
            regRoleSelect.addEventListener('change', (e) => this.toggleRoleSpecificFields(e.target.value));
        }

        // Captcha refresh button
        const refreshBtn = document.getElementById('refresh-captcha-btn');
        if (refreshBtn) {
            refreshBtn.addEventListener('click', () => this.refreshCaptcha());
        }

        // Registration form submit
        const regForm = document.getElementById('register-form');
        if (regForm) {
            regForm.addEventListener('submit', (e) => this.handleRegister(e));
        }

        // Login form submit
        const loginForm = document.getElementById('login-form');
        if (loginForm) {
            loginForm.addEventListener('submit', (e) => this.handleLogin(e));
        }
    },

    toggleRoleSpecificFields(role) {
        const merchantFields = document.getElementById('reg-merchant-fields');
        const deliveryFields = document.getElementById('reg-delivery-fields');

        if (role === 'merchant') {
            merchantFields.classList.remove('hidden');
            deliveryFields.classList.add('hidden');
        } else if (role === 'delivery') {
            deliveryFields.classList.remove('hidden');
            merchantFields.classList.add('hidden');
        } else {
            merchantFields.classList.add('hidden');
            deliveryFields.classList.add('hidden');
        }
    },

    async refreshCaptcha() {
        try {
            const captchaImg = document.getElementById('captcha-image-display');
            const captchaInput = document.getElementById('login-captcha-input');
            if (captchaInput) captchaInput.value = '';

            const res = await fetch('/api/auth/captcha');
            const data = await res.json();
            if (data.status === 'success') {
                this.currentCaptchaId = data.captcha_id;
                captchaImg.src = data.image_base64;
            }
        } catch (e) {
            console.error('Error loading CAPTCHA:', e);
        }
    },

    openLoginModal() {
        document.getElementById('register-modal').classList.add('hidden');
        document.getElementById('login-modal').classList.remove('hidden');
        document.getElementById('login-modal').classList.add('flex');
        this.refreshCaptcha();
    },

    closeLoginModal() {
        document.getElementById('login-modal').classList.add('hidden');
        document.getElementById('login-modal').classList.remove('flex');
    },

    openRegisterModal(preselectRole = 'customer') {
        document.getElementById('login-modal').classList.add('hidden');
        const modal = document.getElementById('register-modal');
        modal.classList.remove('hidden');
        modal.classList.add('flex');

        const roleSelect = document.getElementById('reg-role-select');
        if (roleSelect) {
            roleSelect.value = preselectRole;
            this.toggleRoleSpecificFields(preselectRole);
        }
    },

    closeRegisterModal() {
        document.getElementById('register-modal').classList.add('hidden');
        document.getElementById('register-modal').classList.remove('flex');
    },

    async handleRegister(e) {
        e.preventDefault();
        const role = document.getElementById('reg-role-select').value;
        const name = document.getElementById('reg-name-input').value.trim();
        const mobile = document.getElementById('reg-mobile-input').value.trim();
        const email = document.getElementById('reg-email-input').value.trim();
        const address = document.getElementById('reg-address-input').value.trim();
        const area = document.getElementById('reg-area-input').value.trim() || 'Indiranagar';
        const pincode = document.getElementById('reg-pincode-input').value.trim() || '560038';

        if (!name || !mobile) {
            showToast('Please fill all mandatory fields (Name and Mobile)', 'error');
            return;
        }

        const payload = {
            role,
            name,
            mobile,
            email,
            address,
            area,
            pincode,
            store_name: document.getElementById('reg-store-name-input')?.value || null,
            store_address: document.getElementById('reg-store-addr-input')?.value || null,
            upi_id: document.getElementById('reg-upi-input')?.value || null,
            vehicle_type: document.getElementById('reg-vehicle-type-select')?.value || 'Bike',
            vehicle_number: document.getElementById('reg-vehicle-num-input')?.value || null
        };

        try {
            const res = await fetch('/api/auth/register', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify(payload)
            });

            const data = await res.json();
            if (res.ok && data.status === 'success') {
                this.closeRegisterModal();
                // Step 1 requirement: simulate dummy login credentials SMS modal!
                showSmsCredentialsModal(data.sms_notification, data.credentials);
                showToast('Registration complete! Check your dummy credentials.', 'success');
            } else {
                showToast(data.detail || 'Registration failed. Mobile may already exist.', 'error');
            }
        } catch (err) {
            showToast('Network error during registration', 'error');
        }
    },

    async handleLogin(e) {
        e.preventDefault();
        const loginId = document.getElementById('login-id-input').value.trim();
        const password = document.getElementById('login-password-input').value.trim();
        const captchaText = document.getElementById('login-captcha-input').value.trim();

        if (!loginId || !password) {
            showToast('Please enter User ID / Mobile and Password', 'error');
            return;
        }

        if (!captchaText) {
            showToast('Please solve and enter the CAPTCHA code', 'error');
            return;
        }

        try {
            const res = await fetch('/api/auth/login', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({
                    login_id: loginId,
                    password: password,
                    captcha_id: this.currentCaptchaId,
                    captcha_text: captchaText
                })
            });

            const data = await res.json();
            if (res.ok && data.status === 'success') {
                AppState.currentUser = data.user;
                AppState.currentRole = data.user.role;
                this.closeLoginModal();
                updateAppView();
                showToast(`Welcome back, ${data.user.name}!`, 'success');
            } else {
                showToast(data.detail || 'Login failed. Please check credentials or CAPTCHA.', 'error');
                // Refresh captcha on failed attempt
                this.refreshCaptcha();
            }
        } catch (err) {
            showToast('Network error during login', 'error');
            this.refreshCaptcha();
        }
    },

    openProfileModal() {
        const u = AppState.currentUser;
        if (!u) return;

        document.getElementById('prof-name-input').value = u.name || '';
        document.getElementById('prof-phone-input').value = u.mobile || '';
        document.getElementById('prof-email-input').value = u.email || '';
        document.getElementById('prof-address-input').value = u.address || '';
        document.getElementById('prof-area-input').value = u.area || '';
        document.getElementById('prof-pincode-input').value = u.pincode || '';

        // Role-specific profile toggles
        const vehicleGroup = document.getElementById('prof-vehicle-group');
        const onlineToggleGroup = document.getElementById('prof-online-toggle-group');
        const storeGroup = document.getElementById('prof-store-group');

        if (u.role === 'delivery') {
            vehicleGroup.classList.remove('hidden');
            onlineToggleGroup.classList.remove('hidden');
            document.getElementById('prof-vehicle-num-input').value = u.vehicle_number || '';
            document.getElementById('prof-online-toggle').checked = u.is_online !== false;
        } else {
            vehicleGroup.classList.add('hidden');
            onlineToggleGroup.classList.add('hidden');
        }

        if (u.role === 'merchant' && u.store) {
            storeGroup.classList.remove('hidden');
            document.getElementById('prof-store-name-input').value = u.store.name || '';
        } else {
            storeGroup.classList.add('hidden');
        }

        const modal = document.getElementById('profile-modal');
        modal.classList.remove('hidden');
        modal.classList.add('flex');
    },

    closeProfileModal() {
        const modal = document.getElementById('profile-modal');
        modal.classList.add('hidden');
        modal.classList.remove('flex');
    },

    async handleSaveProfile(e) {
        e.preventDefault();
        const u = AppState.currentUser;
        if (!u) return;

        const payload = {
            name: document.getElementById('prof-name-input').value.trim(),
            email: document.getElementById('prof-email-input').value.trim(),
            address: document.getElementById('prof-address-input').value.trim(),
            area: document.getElementById('prof-area-input').value.trim(),
            pincode: document.getElementById('prof-pincode-input').value.trim()
        };

        if (u.role === 'delivery') {
            payload.vehicle_number = document.getElementById('prof-vehicle-num-input').value.trim();
            payload.is_online = document.getElementById('prof-online-toggle').checked;
        }
        if (u.role === 'merchant') {
            payload.store_name = document.getElementById('prof-store-name-input').value.trim();
        }

        try {
            const res = await fetch(`/api/users/profile?user_id=${u.id}`, {
                method: 'PUT',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify(payload)
            });
            const data = await res.json();
            if (data.status === 'success') {
                showToast('Profile updated successfully!', 'success');
                // Update local current user
                Object.assign(AppState.currentUser, payload);
                this.closeProfileModal();
                updateAppView();
            }
        } catch (err) {
            showToast('Failed to update profile', 'error');
        }
    }
};

document.addEventListener('DOMContentLoaded', () => {
    AuthModule.init();
});
