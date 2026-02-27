import { LightningElement, track } from 'lwc';
import getAvailableAccommodations from '@salesforce/apex/Hostel_AvailabilityController.getAvailableAccommodations';
import createReservation from '@salesforce/apex/Hostel_BookingController.createReservation';

const FAMILY_DORM = 'Dorm Bed';
const FAMILY_PRIVATE = 'Private Room';
const DAY_NAMES = ['SUN', 'MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT'];
const MONTH_NAMES = ['JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN', 'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC'];
const GUEST_OPTIONS = Array.from({ length: 10 }, (_, i) => ({
    label: String(i + 1),
    value: String(i + 1)
}));

export default class HostelBooking extends LightningElement {
    // Search parameters
    checkInDate;
    checkOutDate;
    guestCount = '1';

    // State
    @track accommodations = [];
    @track cartItems = [];
    @track expandedIds = {};
    isLoading = false;
    isBooking = false;
    error;
    bookingSuccess;

    // --- Lifecycle ---

    connectedCallback() {
        const today = new Date();
        const tomorrow = new Date(today);
        tomorrow.setDate(tomorrow.getDate() + 1);
        this.checkInDate = this._toIsoDate(today);
        this.checkOutDate = this._toIsoDate(tomorrow);
        this._fetchAvailability();
    }

    // --- Imperative Apex ---

    _fetchAvailability() {
        this.isLoading = true;
        getAvailableAccommodations({
            checkInDate: this.checkInDate,
            checkOutDate: this.checkOutDate,
            guests: parseInt(this.guestCount, 10) || 1
        })
            .then(data => {
                this.accommodations = data.map(item => ({ ...item }));
                this.error = undefined;
                // Remove cart items whose product is no longer in results
                this.cartItems = this.cartItems.filter(ci =>
                    this.accommodations.some(a => a.productId === ci.productId)
                );
            })
            .catch(err => {
                this.error = err.body ? err.body.message : 'An error occurred';
                this.accommodations = [];
            })
            .finally(() => {
                this.isLoading = false;
            });
    }

    // --- Getters ---

    get guestOptions() {
        return GUEST_OPTIONS;
    }

    get roomSections() {
        const sections = [];
        const dorms = this.accommodations
            .filter(a => a.family === FAMILY_DORM)
            .map(a => this._enrichAccommodation(a));
        if (dorms.length > 0) sections.push({ key: 'dorm', label: 'Dorm Rooms', rooms: dorms });

        const privates = this.accommodations
            .filter(a => a.family === FAMILY_PRIVATE)
            .map(a => this._enrichAccommodation(a));
        if (privates.length > 0) sections.push({ key: 'private', label: 'Private Rooms', rooms: privates });

        return sections;
    }

    get hasResults() {
        return this.accommodations.length > 0;
    }

    get hasNoResults() {
        return !this.isLoading && this.accommodations.length === 0 && !this.error;
    }

    get hasCartItems() {
        return this.cartItems.length > 0;
    }

    get hasNoCartItems() {
        return !this.hasCartItems;
    }

    get isBookNowDisabled() {
        return !this.hasCartItems || this.isBooking;
    }

    get bookNowClass() {
        return this.hasCartItems
            ? 'book-now-btn book-now-active'
            : 'book-now-btn book-now-inactive';
    }

    get nightCount() {
        if (!this.checkInDate || !this.checkOutDate) return 1;
        const ci = new Date(this.checkInDate + 'T00:00:00');
        const co = new Date(this.checkOutDate + 'T00:00:00');
        const diff = Math.round((co - ci) / (1000 * 60 * 60 * 24));
        return diff > 0 ? diff : 1;
    }

    get nightLabel() {
        return this.nightCount === 1 ? 'NIGHT' : 'NIGHTS';
    }

    get dateRangeLabel() {
        return this._formatShortDate(this.checkInDate) + ' - ' + this._formatShortDate(this.checkOutDate);
    }

    get enrichedCartItems() {
        return this.cartItems.map(item => {
            const nights = this.nightCount;
            const isPerson = item.pricingModel === 'Per Person';
            const qty = item.quantity;
            const lineTotal = item.rate * qty * nights;
            const qtyLabel = isPerson
                ? qty + (qty === 1 ? ' person' : ' persons') + ' for ' + nights + (nights === 1 ? ' night' : ' nights')
                : qty + (qty === 1 ? ' room' : ' rooms') + ' for ' + nights + (nights === 1 ? ' night' : ' nights');
            const qtyFieldLabel = isPerson ? 'No. of guests' : 'No. of rooms';

            const maxQty = this._getMaxQuantity(item);
            const qtyOptions = [];
            for (let i = 1; i <= maxQty; i++) {
                qtyOptions.push({ label: String(i), value: String(i) });
            }

            return Object.assign({}, item, {
                lineTotal,
                formattedTotal: '$' + lineTotal.toFixed(2),
                qtyLabel,
                qtyFieldLabel,
                qtyOptions,
                quantityStr: String(qty),
                dateRange: this.dateRangeLabel,
                nightCount: nights + ' ' + this.nightLabel
            });
        });
    }

    // --- Handlers ---

    handleCheckInChange(event) {
        this.checkInDate = event.detail.value;
        if (this.checkOutDate <= this.checkInDate) {
            const next = new Date(this.checkInDate + 'T00:00:00');
            next.setDate(next.getDate() + 1);
            this.checkOutDate = this._toIsoDate(next);
        }
        this._fetchAvailability();
    }

    handleCheckOutChange(event) {
        this.checkOutDate = event.detail.value;
        this._fetchAvailability();
    }

    handleGuestChange(event) {
        this.guestCount = event.detail.value;
        this._fetchAvailability();
    }

    handleToggleSelect(event) {
        const productId = event.currentTarget.dataset.id;
        const existing = this.cartItems.find(ci => ci.productId === productId);
        if (existing) {
            this.cartItems = this.cartItems.filter(ci => ci.productId !== productId);
        } else {
            const acc = this.accommodations.find(a => a.productId === productId);
            if (acc) {
                const guests = parseInt(this.guestCount, 10) || 1;
                const isPerson = acc.pricingModel === 'Per Person';
                const qty = isPerson ? Math.min(guests, acc.availableUnits) : 1;
                this.cartItems = [...this.cartItems, {
                    productId: acc.productId,
                    name: acc.name,
                    rate: acc.rate,
                    pricingModel: acc.pricingModel,
                    quantity: qty,
                    availableUnits: acc.availableUnits
                }];
            }
        }
    }

    handleToggleExpand(event) {
        const productId = event.currentTarget.dataset.id;
        this.expandedIds = Object.assign({}, this.expandedIds, {
            [productId]: !this.expandedIds[productId]
        });
    }

    handleCartQuantityChange(event) {
        const productId = event.currentTarget.dataset.id;
        const newQty = parseInt(event.detail.value, 10);
        this.cartItems = this.cartItems.map(ci => {
            if (ci.productId === productId) return Object.assign({}, ci, { quantity: newQty });
            return ci;
        });
    }

    handleRemoveItem(event) {
        const productId = event.currentTarget.dataset.id;
        this.cartItems = this.cartItems.filter(ci => ci.productId !== productId);
    }

    handleBookNow() {
        if (!this.hasCartItems || this.isBooking) return;

        this.isBooking = true;
        this.error = undefined;
        this.bookingSuccess = undefined;

        const items = this.cartItems.map(ci => ({
            productId: ci.productId,
            quantity: ci.quantity
        }));

        createReservation({
            checkInDate: this.checkInDate,
            checkOutDate: this.checkOutDate,
            guests: parseInt(this.guestCount, 10) || 1,
            itemsJson: JSON.stringify(items)
        })
            .then(oppId => {
                this.bookingSuccess = 'Reservation created successfully! (ID: ' + oppId + ')';
                this.cartItems = [];
                this._fetchAvailability();
            })
            .catch(err => {
                this.error = err.body ? err.body.message : 'Booking failed. Please try again.';
            })
            .finally(() => {
                this.isBooking = false;
            });
    }

    // --- Private Helpers ---

    _enrichAccommodation(acc) {
        const isSelected = this.cartItems.some(ci => ci.productId === acc.productId);
        const isExpanded = !!this.expandedIds[acc.productId];
        const isPerson = acc.pricingModel === 'Per Person';
        const rateLabel = isPerson ? 'PER PERSON' : 'PER ROOM';

        // Gender icon styling
        let genderClass, iconCount;
        if (acc.gender === "Women's") {
            genderClass = 'gender-icon gender-female';
            iconCount = 1;
        } else if (acc.gender === "Men's") {
            genderClass = 'gender-icon gender-male';
            iconCount = 1;
        } else if (acc.gender === 'Mixed') {
            genderClass = 'gender-icon gender-mixed';
            iconCount = 2;
        } else {
            genderClass = 'gender-icon gender-private';
            iconCount = Math.min(acc.maxGuests, 6);
        }
        const genderIcons = Array.from({ length: iconCount }, (_, i) => ({ key: i }));

        // Availability badge
        const availLabel = acc.availableUnits + ' LEFT!';
        const availClass = acc.availableUnits <= 2 ? 'avail-badge avail-low' : 'avail-badge';

        // Amenities as list
        const amenitiesList = acc.amenities
            ? acc.amenities.split('\n').filter(Boolean).map((text, i) => ({ key: i, text }))
            : [];

        const formattedRate = acc.rate != null ? '$' + acc.rate.toFixed(2) : '';
        const priceDollars = acc.rate != null ? '$' + Math.floor(acc.rate) : '';
        const priceCents = acc.rate != null ? '.' + acc.rate.toFixed(2).split('.')[1] : '';

        const chevronIcon = isExpanded ? 'utility:chevronup' : 'utility:chevrondown';
        const cardClass = 'room-card' + (isSelected ? ' room-card-selected' : '');

        return Object.assign({}, acc, {
            isSelected,
            isExpanded,
            rateLabel,
            genderClass,
            genderIcons,
            availLabel,
            availClass,
            amenitiesList,
            hasAmenities: amenitiesList.length > 0,
            hasImage: !!acc.imageUrl,
            formattedRate,
            priceDollars,
            priceCents,
            chevronIcon,
            cardClass
        });
    }

    _getMaxQuantity(cartItem) {
        const acc = this.accommodations.find(a => a.productId === cartItem.productId);
        return acc ? acc.availableUnits : 1;
    }

    _toIsoDate(d) {
        const year = d.getFullYear();
        const month = String(d.getMonth() + 1).padStart(2, '0');
        const day = String(d.getDate()).padStart(2, '0');
        return `${year}-${month}-${day}`;
    }

    _formatShortDate(isoStr) {
        if (!isoStr) return '';
        const d = new Date(isoStr + 'T00:00:00');
        return DAY_NAMES[d.getDay()] + ' ' + MONTH_NAMES[d.getMonth()] + ' ' + d.getDate();
    }
}
