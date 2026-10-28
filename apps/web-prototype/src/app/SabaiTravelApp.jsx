import { useState, useRef, useEffect } from 'react';
import { Wifi } from 'lucide-react';
import { TabBar, Toast } from '../components/ui';
import { DESTINATIONS, LISTINGS } from '../data/catalog';
import { refundFor } from '../domain/bookings';
import { addDaysISO, fmtDate, fmtRange } from '../domain/dates';
import { buildItinerary } from '../domain/itinerary';
import { describeApiErrorTh } from '../repositories/errors';
import { LoginScreen, RegisterScreen } from '../features/auth/AuthScreens';
import { BookingScreen, ConfirmationScreen, PaymentScreen } from '../features/booking/CheckoutScreens';
import { BookingDetailScreen, BookingsScreen, CancelBookingScreen } from '../features/booking/MyBookingsScreens';
import { CommunityScreen, CommunitySheet, CreatePostScreen, GroupDetailScreen, MemberScreen, PostDetailScreen } from '../features/community/CommunityScreens';
import { useCommunity } from '../features/community/useCommunity';
import { CouponScreen } from '../features/coupons/CouponScreen';
import { HelpScreen, SupportTicketScreen } from '../features/help/HelpScreens';
import { HomeScreen } from '../features/home/HomeScreen';
import { NotificationScreen } from '../features/notifications/NotificationScreen';
import { ProfileScreen } from '../features/profile/ProfileScreen';
import { ReviewsScreen, WriteReviewScreen } from '../features/reviews/ReviewScreens';
import { ListingDetailScreen, SearchScreen } from '../features/search/SearchScreens';
import { ChangePasswordScreen, SettingsScreen } from '../features/settings/SettingsScreens';
import { AddEventScreen, TripSetupScreen, TripsHub } from '../features/travel/TravelScreens';
import { useReminderEngine } from '../features/travel/useReminderEngine';
import { useTravelHub } from '../features/travel/useTravelHub';
import { AiPlannerScreen } from '../features/trips/AiPlannerScreen';
import { TripDetailScreen } from '../features/trips/TripsScreens';
import { WalletScreen } from '../features/wallet/WalletScreen';
import { FONT_CSS } from '../theme/fontCss';
import { TYPE_LABEL } from '../ui/typeMeta';

export default function SabaiTravelApp({ repo, snapshot }) {
  const [stack, setStack] = useState(['login']);
  const screen = stack[stack.length - 1];
  const push = (s) => setStack((prev) => [...prev, s]);
  const pop = () => setStack((prev) => (prev.length > 1 ? prev.slice(0, -1) : prev));
  const gotoTab = (tab) => setStack([tab]);

  const [loginEmail, setLoginEmail] = useState('');
  const [loginPassword, setLoginPassword] = useState('');

  const [searchQuery, setSearchQuery] = useState('');
  const [searchCategory, setSearchCategory] = useState('ทั้งหมด');
  const [selectedListing, setSelectedListing] = useState(null);

  const [aiDestination, setAiDestination] = useState('เชียงใหม่');
  const [aiDays, setAiDays] = useState(3);
  const [aiBudget, setAiBudget] = useState(10000);
  const [aiStyles, setAiStyles] = useState(['ธรรมชาติ', 'อาหารท้องถิ่น']);
  const [aiTravelers, setAiTravelers] = useState(2);
  const [aiGenerating, setAiGenerating] = useState(false);
  const [aiResult, setAiResult] = useState(null);
  const [aiSaved, setAiSaved] = useState(false);
  const [savedTrips, setSavedTrips] = useState([]);

  const [bookingItem, setBookingItem] = useState(null);
  const [paymentMethod, setPaymentMethod] = useState('promptpay');
  const [processingPayment, setProcessingPayment] = useState(false);
  const [bookingNumber, setBookingNumber] = useState('');

  const [registerForm, setRegisterForm] = useState({
    firstName: '', lastName: '', email: '', phone: '', password: '', confirmPassword: '',
    gender: 'หญิง', dob: '', nationality: 'ไทย', language: 'ไทย',
    budgetLevel: 'ปานกลาง', travelStyles: [], favoriteDestination: '', travelWith: 'คู่รัก',
  });
  const updateRegisterForm = (patch) => setRegisterForm((prev) => ({ ...prev, ...patch }));
  const toggleRegisterStyle = (s) => setRegisterForm((prev) => ({
    ...prev,
    travelStyles: prev.travelStyles.includes(s) ? prev.travelStyles.filter((x) => x !== s) : [...prev.travelStyles, s],
  }));
  const [authBusy, setAuthBusy] = useState(false);
  const [authError, setAuthError] = useState('');
  const runAuth = async (action) => {
    setAuthError('');
    setAuthBusy(true);
    try {
      await action();
      gotoTab('home');
    } catch (e) {
      setAuthError(describeApiErrorTh(e));
    } finally {
      setAuthBusy(false);
    }
  };
  const handleLogin = () => runAuth(() => repo.auth.login({ email: loginEmail.trim(), password: loginPassword }));
  const handleFinishRegister = () => runAuth(() => repo.auth.register({
    email: registerForm.email.trim(), password: registerForm.password,
    displayName: `${registerForm.firstName} ${registerForm.lastName}`.trim(),
  }));
  const handleLogout = () => { repo.auth.logout(); setAuthError(''); setStack(['login']); };

  const [walletBalance, setWalletBalance] = useState(snapshot.walletBalance);
  const [walletTransactions, setWalletTransactions] = useState(snapshot.walletTransactions);
  const handleTopUp = () => {
    setWalletBalance((prev) => prev + 1000);
    setWalletTransactions((prev) => [{ id: Date.now(), type: 'in', label: 'เติมเงินผ่านพร้อมเพย์', date: 'วันนี้', amount: 1000 }, ...prev]);
  };

  const [selectedTrip, setSelectedTrip] = useState(null);

  const [notifications, setNotifications] = useState(snapshot.notifications);
  const unreadCount = notifications.filter((n) => !n.read).length;
  const handleMarkAllRead = () => setNotifications((prev) => prev.map((n) => ({ ...n, read: true })));
  const handleMarkOneRead = (id) => setNotifications((prev) => prev.map((n) => (n.id === id ? { ...n, read: true } : n)));

  const [reviews, setReviews] = useState(snapshot.reviews);
  const [writeReviewItem, setWriteReviewItem] = useState(null);
  const [writeReviewRating, setWriteReviewRating] = useState(0);
  const [writeReviewComment, setWriteReviewComment] = useState('');
  const handleSubmitReview = () => {
    setReviews((prev) => [{ id: Date.now(), itemName: writeReviewItem.name, itemType: writeReviewItem.type, rating: writeReviewRating, comment: writeReviewComment, date: 'วันนี้' }, ...prev]);
    setWriteReviewItem(null);
    setWriteReviewRating(0);
    setWriteReviewComment('');
    pop();
  };

  const [coupons, setCoupons] = useState(snapshot.coupons);
  const handleApplyCoupon = (coupon) => {
    setCoupons((prev) => prev.map((c) => (c.id === coupon.id ? { ...c, status: 'used' } : c)));
  };

  const [supportTickets, setSupportTickets] = useState(snapshot.supportTickets);
  const [ticketSubject, setTicketSubject] = useState('');
  const [ticketMessage, setTicketMessage] = useState('');
  const handleSubmitTicket = () => {
    setSupportTickets((prev) => [{ id: Date.now(), subject: ticketSubject, message: ticketMessage, date: 'วันนี้' }, ...prev]);
    setTicketSubject('');
    setTicketMessage('');
    pop();
  };

  const [bookings, setBookings] = useState(snapshot.bookings);
  const [selectedBookingId, setSelectedBookingId] = useState(null);
  const selectedBooking = bookings.find((b) => b.id === selectedBookingId) || null;
  const [cancelReason, setCancelReason] = useState('');
  const [paymentError, setPaymentError] = useState('');

  const [settings, setSettings] = useState({ language: 'ไทย', currency: 'THB ฿', theme: 'สว่าง', notif: { push: true, email: true, trip: true, promo: false } });
  const [systemDark, setSystemDark] = useState(false);
  useEffect(() => {
    try {
      const mq = window.matchMedia('(prefers-color-scheme: dark)');
      setSystemDark(mq.matches);
      const onChange = (e) => setSystemDark(e.matches);
      mq.addEventListener('change', onChange);
      return () => mq.removeEventListener('change', onChange);
    } catch { return undefined; }
  }, []);
  const isDark = settings.theme === 'มืด' || (settings.theme === 'ตามระบบ' && systemDark);

  const [toast, setToast] = useState(null);
  const toastTimer = useRef(null);
  const showToast = (message) => {
    setToast(message);
    clearTimeout(toastTimer.current);
    toastTimer.current = setTimeout(() => setToast(null), 2400);
  };
  const pushNotification = (type, title, message) =>
    setNotifications((prev) => [{ id: Date.now() + Math.random(), type, title, message, time: 'เมื่อสักครู่', read: false }, ...prev]);

  const cm = useCommunity({
    showToast, pushNotification, seed: snapshot.community,
    onSaveTrip: (post) => setSavedTrips((prev) => [...prev, {
      id: Date.now(), destination: post.destination, days: post.sharedTrip.days, budget: post.sharedTrip.budget, travelers: 2,
      itinerary: buildItinerary({ destinationName: post.destination, days: post.sharedTrip.days, budget: post.sharedTrip.budget, styles: post.sharedTrip.styles }),
    }]),
  });
  const nav = { push, pop };
  const hub = useTravelHub({ showToast, initialEvents: snapshot.events });
  const plans = bookings.filter((b) => b.plan && b.status !== 'cancelled').map((b) => ({ ...b.plan, id: b.id, number: b.number }));
  const remindersOn = settings.notif.trip !== false;
  const fireReminder = (r, { silent = false } = {}) => {
    pushNotification('reminder', r.title, r.body);
    if (!silent) showToast(r.title);
    try {
      if (hub.prefs.browser && typeof Notification !== 'undefined' && Notification.permission === 'granted') new Notification(r.title, { body: r.body });
    } catch { /* การแจ้งเตือนผ่านเบราว์เซอร์เป็นส่วนเสริม ไม่กระทบการทำงานหลัก */ }
  };
  useReminderEngine({ hub, plans, enabled: remindersOn, onFire: fireReminder });

  const handleSettingsChange = (patch) => {
    setSettings((prev) => ({ ...prev, ...patch }));
    if (!patch.notif && !patch.theme) showToast('บันทึกการตั้งค่าแล้ว');
  };
  const handleChangePassword = () => { showToast('เปลี่ยนรหัสผ่านเรียบร้อยแล้ว'); pop(); };
  const handleDeleteAccount = () => {
    setStack(['login']);
    setSavedTrips([]);
    showToast('ลบบัญชีเรียบร้อยแล้ว');
  };

  const handleSelectBooking = (id) => { setSelectedBookingId(id); push('booking-detail'); };
  const handleReviewBooking = () => {
    const match = LISTINGS.find((l) => l.name === selectedBooking.title);
    if (match) setWriteReviewItem(match);
    push('write-review');
  };
  const handleConfirmCancel = () => {
    const b = selectedBooking;
    const refund = refundFor(b);
    setBookings((prev) => prev.map((x) => (x.id === b.id ? { ...x, status: 'cancelled', cancelReason, refund } : x)));
    setWalletBalance((prev) => prev + refund);
    setWalletTransactions((prev) => [{ id: Date.now(), type: 'in', label: `เงินคืนจากการยกเลิก ${b.title}`, date: 'วันนี้', amount: refund }, ...prev]);
    pushNotification('booking', 'ยกเลิกการจองแล้ว', `${b.title} (${b.number}) ถูกยกเลิก เงินคืน ฿${refund.toLocaleString()} เข้า Sabai Wallet แล้ว`);
    setCancelReason('');
    showToast(`ยกเลิกแล้ว คืนเงิน ฿${refund.toLocaleString()} เข้า Wallet`);
    pop();
  };

  const toggleAiStyle = (s) => setAiStyles((prev) => (prev.includes(s) ? prev.filter((x) => x !== s) : [...prev, s]));

  const handleGenerateAi = () => {
    setAiGenerating(true);
    setAiSaved(false);
    setTimeout(() => {
      setAiResult(buildItinerary({ destinationName: aiDestination, days: aiDays, budget: aiBudget, styles: aiStyles }));
      setAiGenerating(false);
    }, 1700);
  };
  const handleResetAi = () => setAiResult(null);
  const [aiSaving, setAiSaving] = useState(false);
  const handleSaveAiTrip = async () => {
    if (aiSaved || aiSaving) return;
    setAiSaving(true);
    try {
      const destination = DESTINATIONS.find((d) => d.name === aiDestination);
      // Persist through the repository; the server model has no itinerary yet, so the itinerary stays in local state.
      const remote = await repo.trips.create({ name: `ทริป${aiDestination} ${aiDays} วัน`, destinationId: destination ? destination.id : '' });
      const total = aiResult.budgetBreakdown.reduce((s, b) => s + b.value, 0);
      setSavedTrips((prev) => [...prev, { id: remote.id, destination: aiDestination, days: aiDays, budget: total, travelers: aiTravelers, itinerary: aiResult }]);
      setAiSaved(true);
    } catch (e) {
      showToast(describeApiErrorTh(e));
    } finally {
      setAiSaving(false);
    }
  };
  const handleBookAiTrip = () => {
    hub.resetSetup();
    push('trip-setup');
  };
  const handleSetupContinue = (pricing) => {
    const { startDate, outbound, ret, skip } = hub.setup;
    const endDate = addDaysISO(startDate, aiDays - 1);
    const plan = { destination: aiDestination, days: aiDays, travelers: aiTravelers, startDate, endDate, outbound: skip ? null : outbound, ret: skip ? null : ret, skipFlights: skip, itinerary: aiResult };
    const flightPart = skip ? 'ไม่รวมเที่ยวบิน' : `${outbound.airline} / ${ret.airline}`;
    setBookingItem({
      title: `ทริป ${aiDestination} ${aiDays} วัน`,
      subtitle: `${fmtRange(startDate, endDate)} · ${aiTravelers} ผู้เดินทาง · ${flightPart}`,
      price: pricing.total, type: 'trip', plan,
      breakdown: [['แพ็กเกจทริป (ไม่รวมเที่ยวบิน)', `฿${pricing.base.toLocaleString()}`], ...(skip ? [] : [[`ขาไป ${outbound.number} · ${fmtDate(startDate)}`, `฿${(outbound.price * aiTravelers).toLocaleString()}`], [`ขากลับ ${ret.number} · ${fmtDate(endDate)}`, `฿${(ret.price * aiTravelers).toLocaleString()}`]])],
    });
    push('booking');
  };

  const filteredListings = LISTINGS.filter((l) => {
    const catMatch = searchCategory === 'ทั้งหมด' || TYPE_LABEL[l.type] === searchCategory;
    const qMatch = searchQuery === '' || l.name.includes(searchQuery) || l.location.includes(searchQuery);
    return catMatch && qMatch;
  });

  const handleSelectListing = (item) => { setSelectedListing(item); push('listing-detail'); };
  const handleBookListing = () => {
    setBookingItem({ title: selectedListing.name, subtitle: selectedListing.location, price: selectedListing.price, type: selectedListing.type });
    push('booking');
  };
  const handleQuickAction = (label) => { setSearchCategory(label); setSearchQuery(''); push('search'); };
  const handleDestinationTap = (d) => { setSearchQuery(d.name); setSearchCategory('ทั้งหมด'); push('search'); };

  const PAYMENT_LABEL = { promptpay: 'พร้อมเพย์ (PromptPay)', card: 'บัตรเครดิต/เดบิต', wallet: 'Sabai Wallet' };
  const handleConfirmPayment = () => {
    const total = Math.round(bookingItem.price * 1.05);
    if (paymentMethod === 'wallet' && total > walletBalance) {
      setPaymentError(`ยอด Sabai Wallet ไม่เพียงพอ (คงเหลือ ฿${walletBalance.toLocaleString()}) กรุณาเติมเงินหรือเลือกวิธีชำระอื่น`);
      return;
    }
    setPaymentError('');
    setProcessingPayment(true);
    setTimeout(() => {
      const number = 'SB' + Math.floor(100000 + Math.random() * 900000);
      setProcessingPayment(false);
      setBookingNumber(number);
      setBookings((prev) => [{ id: 'b' + Date.now(), number, type: bookingItem.type, title: bookingItem.title, subtitle: bookingItem.subtitle, amount: total, method: PAYMENT_LABEL[paymentMethod], date: 'วันนี้', status: 'confirmed', ...(bookingItem.plan ? { plan: bookingItem.plan } : {}) }, ...prev]);
      if (paymentMethod === 'wallet') {
        setWalletBalance((prev) => prev - total);
        setWalletTransactions((prev) => [{ id: Date.now(), type: 'out', label: `ชำระค่าจอง ${bookingItem.title}`, date: 'วันนี้', amount: total }, ...prev]);
      }
      pushNotification('booking', 'ยืนยันการจองสำเร็จ', `${bookingItem.title} หมายเลข ${number} ได้รับการยืนยันแล้ว`);
      if (bookingItem.plan) pushNotification('trip', 'เพิ่มทริปลงปฏิทินแล้ว', `ทริป${bookingItem.plan.destination} ${fmtRange(bookingItem.plan.startDate, bookingItem.plan.endDate)} อยู่ในปฏิทินและเลขาส่วนตัวของคุณแล้ว`);
      pushNotification('payment', 'ชำระเงินสำเร็จ', `ชำระเงิน ฿${total.toLocaleString()} ผ่าน ${PAYMENT_LABEL[paymentMethod]} เรียบร้อยแล้ว`);
      push('confirmation');
    }, 1600);
  };

  const handleBackToHome = () => {
    setStack(['home']);
    setAiResult(null);
    setAiSaved(false);
    setBookingItem(null);
  };

  const showTabBar = ['home', 'search', 'ai', 'trips', 'community', 'profile'].includes(screen);

  let content = null;
  if (screen === 'login') {
    content = <LoginScreen email={loginEmail} setEmail={setLoginEmail} password={loginPassword} setPassword={setLoginPassword} onLogin={handleLogin} error={authError} busy={authBusy} onGuest={() => gotoTab('home')} onRegister={() => push('register-1')} />;
  } else if (screen === 'register-1') {
    content = <RegisterScreen step={1} form={registerForm} onChange={updateRegisterForm} onToggleStyle={toggleRegisterStyle} onBack={pop} onNext={() => push('register-2')} />;
  } else if (screen === 'register-2') {
    content = <RegisterScreen step={2} form={registerForm} onChange={updateRegisterForm} onToggleStyle={toggleRegisterStyle} onBack={pop} onNext={() => push('register-3')} />;
  } else if (screen === 'register-3') {
    content = <RegisterScreen step={3} form={registerForm} onChange={updateRegisterForm} onToggleStyle={toggleRegisterStyle} onBack={pop} onFinish={handleFinishRegister} error={authError} busy={authBusy} />;
  } else if (screen === 'wallet') {
    content = <WalletScreen balance={walletBalance} transactions={walletTransactions} onBack={pop} onTopUp={handleTopUp} />;
  } else if (screen === 'trip-detail') {
    content = <TripDetailScreen trip={selectedTrip} onBack={pop} />;
  } else if (screen === 'notifications') {
    content = <NotificationScreen notifications={notifications} onBack={pop} onMarkAll={handleMarkAllRead} onMarkOne={handleMarkOneRead} />;
  } else if (screen === 'reviews') {
    content = <ReviewsScreen reviews={reviews} onBack={pop} onWriteReview={() => push('write-review')} />;
  } else if (screen === 'write-review') {
    content = (
      <WriteReviewScreen
        selectedItem={writeReviewItem} onSelectItem={setWriteReviewItem}
        rating={writeReviewRating} setRating={setWriteReviewRating}
        comment={writeReviewComment} setComment={setWriteReviewComment}
        onBack={pop} onSubmit={handleSubmitReview}
      />
    );
  } else if (screen === 'bookings') {
    content = <BookingsScreen bookings={bookings} onBack={pop} onSelect={handleSelectBooking} onStartSearch={() => { setSearchCategory('ทั้งหมด'); setSearchQuery(''); gotoTab('search'); }} />;
  } else if (screen === 'booking-detail') {
    content = <BookingDetailScreen booking={selectedBooking} onBack={pop} onCancel={() => push('cancel-booking')} onReview={selectedBooking && LISTINGS.some((l) => l.name === selectedBooking.title) ? handleReviewBooking : undefined} />;
  } else if (screen === 'cancel-booking') {
    content = <CancelBookingScreen booking={selectedBooking} reason={cancelReason} setReason={setCancelReason} onBack={pop} onConfirm={handleConfirmCancel} />;
  } else if (screen === 'settings') {
    content = <SettingsScreen settings={settings} onChange={handleSettingsChange} onChangePassword={() => push('change-password')} onDeleteAccount={handleDeleteAccount} onBack={pop} />;
  } else if (screen === 'change-password') {
    content = <ChangePasswordScreen onBack={pop} onSubmit={handleChangePassword} />;
  } else if (screen === 'coupons') {
    content = <CouponScreen coupons={coupons} onBack={pop} onApply={handleApplyCoupon} />;
  } else if (screen === 'help') {
    content = <HelpScreen onBack={pop} onOpenTicket={() => push('support-ticket')} tickets={supportTickets} />;
  } else if (screen === 'support-ticket') {
    content = (
      <SupportTicketScreen
        subject={ticketSubject} setSubject={setTicketSubject}
        message={ticketMessage} setMessage={setTicketMessage}
        onBack={pop} onSubmit={handleSubmitTicket}
      />
    );
  } else if (screen === 'home') {
    content = <HomeScreen onSearchTap={() => { setSearchCategory('ทั้งหมด'); setSearchQuery(''); push('search'); }} onQuickAction={handleQuickAction} onAiTap={() => push('ai')} onDestinationTap={handleDestinationTap} onNotificationsTap={() => push('notifications')} unreadCount={unreadCount} />;
  } else if (screen === 'search') {
    content = <SearchScreen query={searchQuery} setQuery={setSearchQuery} category={searchCategory} setCategory={setSearchCategory} results={filteredListings} onSelect={handleSelectListing} />;
  } else if (screen === 'listing-detail') {
    content = <ListingDetailScreen item={selectedListing} onBack={pop} onBook={handleBookListing} />;
  } else if (screen === 'ai') {
    content = (
      <AiPlannerScreen
        destination={aiDestination} setDestination={setAiDestination}
        days={aiDays} setDays={setAiDays}
        budget={aiBudget} setBudget={setAiBudget}
        styles={aiStyles} toggleStyle={toggleAiStyle}
        travelers={aiTravelers} setTravelers={setAiTravelers}
        generating={aiGenerating} result={aiResult}
        onGenerate={handleGenerateAi} onReset={handleResetAi}
        onSave={handleSaveAiTrip} onBookTrip={handleBookAiTrip} saved={aiSaved}
      />
    );
  } else if (screen === 'trips') {
    content = <TripsHub hub={hub} plans={plans} remindersOn={remindersOn} onTestReminder={(r) => fireReminder(r)} savedTrips={savedTrips} nav={nav} showToast={showToast} onStartAi={() => push('ai')} onSelectTrip={(t) => { setSelectedTrip(t); push('trip-detail'); }} onOpenPlan={(pl) => handleSelectBooking(pl.id)} />;
  } else if (screen === 'trip-setup') {
    content = <TripSetupScreen hub={hub} plans={plans} nav={nav} draft={aiResult ? { destination: aiDestination, days: aiDays, travelers: aiTravelers, itinerary: aiResult } : null} onContinue={handleSetupContinue} />;
  } else if (screen === 'add-event') {
    content = <AddEventScreen hub={hub} plans={plans} nav={nav} />;
  } else if (screen === 'community') {
    content = <CommunityScreen cm={cm} nav={nav} />;
  } else if (screen === 'post-detail') {
    content = <PostDetailScreen cm={cm} nav={nav} />;
  } else if (screen === 'create-post') {
    content = <CreatePostScreen cm={cm} nav={nav} />;
  } else if (screen === 'member') {
    content = <MemberScreen cm={cm} nav={nav} />;
  } else if (screen === 'group-detail') {
    content = <GroupDetailScreen cm={cm} nav={nav} />;
  } else if (screen === 'profile') {
    content = <ProfileScreen onCommunityTap={() => { cm.selectMember('me'); push('member'); }} onLogout={handleLogout} onWalletTap={() => push('wallet')} onReviewsTap={() => push('reviews')} onCouponTap={() => push('coupons')} onHelpTap={() => push('help')} onBookingsTap={() => push('bookings')} onSettingsTap={() => push('settings')} />;
  } else if (screen === 'booking') {
    content = <BookingScreen item={bookingItem} onBack={pop} onPay={() => push('payment')} />;
  } else if (screen === 'payment') {
    content = <PaymentScreen total={bookingItem ? Math.round(bookingItem.price * 1.05) : 0} method={paymentMethod} setMethod={(m) => { setPaymentMethod(m); setPaymentError(''); }} error={paymentError} onBack={pop} onConfirm={handleConfirmPayment} processing={processingPayment} walletBalance={walletBalance} />;
  } else if (screen === 'confirmation') {
    content = <ConfirmationScreen bookingNumber={bookingNumber} item={bookingItem} onHome={handleBackToHome} onViewBookings={() => { setStack(['profile', 'bookings']); setBookingItem(null); }} onViewCalendar={() => { hub.openCalendar(bookingItem.plan.startDate); setStack(['trips']); setBookingItem(null); }} />;
  }

  return (
    <div style={{ minHeight: '700px', width: '100%', display: 'flex', alignItems: 'center', justifyContent: 'center', background: 'radial-gradient(circle at 25% 15%, #1C5C57 0%, #0B2422 55%, #071614 100%)', padding: '28px 14px', fontFamily: "'Plus Jakarta Sans', sans-serif" }}>
      <style>{FONT_CSS}</style>
      <div className={isDark ? 'theme-dark' : ''} style={{ width: '100%', maxWidth: 390, height: 'min(830px, 92vh)', background: 'var(--paper)', borderRadius: 40, boxShadow: '0 40px 70px -25px rgba(0,0,0,0.55), 0 0 0 9px #0B2422', overflow: 'hidden', display: 'flex', flexDirection: 'column', position: 'relative' }}>
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', padding: '12px 24px 4px', fontSize: 12, fontWeight: 700, color: 'var(--ink)', flexShrink: 0 }}>
          <span>9:41</span>
          <div style={{ display: 'flex', alignItems: 'center', gap: 6 }}>
            <Wifi size={13} />
            <div style={{ width: 22, height: 11, border: '1.4px solid var(--ink)', borderRadius: 3, position: 'relative', display: 'flex', alignItems: 'center', padding: 1 }}>
              <div style={{ width: '75%', height: '100%', background: 'var(--ink)', borderRadius: 1 }} />
            </div>
          </div>
        </div>
        <div style={{ flex: 1, minHeight: 0, display: 'flex', flexDirection: 'column' }}>
          {content}
        </div>
        {showTabBar && <TabBar active={screen} onChange={gotoTab} />}
        <CommunitySheet cm={cm} />
        <Toast message={toast} />
      </div>
    </div>
  );
}
