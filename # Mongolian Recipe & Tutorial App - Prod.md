# Mongolian Recipe & Tutorial App - Production Plan

**Last Updated:** February 2, 2026  
**Status:** Pre-Development Planning Phase  
**Target Platform:** iOS & Android (Flutter/Dart)

---

## 📋 Executive Summary

A mobile application providing cooking recipes and tutorials in Mongolian language, designed for home cooks wanting to expand their skills from simple desserts to restaurant-quality dishes. The app features free and premium content with a subscription model, optimized for performance on low-end devices with modern glassmorphism UI.

### Core Value Proposition
- **Target Audience:** Mongolian wives and home cooks
- **Content:** Traditional Mongolian and international recipes with step-by-step tutorials
- **Monetization:** Premium subscription for exclusive high-quality recipes
- **Language:** Mongolian only
- **Performance:** Optimized for low-entry devices with smooth animations

---

## 🎯 App Features

### 1. Core Features (MVP)

#### 1.1 Recipe Browsing
- **Home Screen**:
  - Trending Recipes section
  - Personalized Recommendations
  - Category browsing
  - Search functionality
  
- **Recipe Categories**:
  - Desserts (Амттан)
  - Main Dishes (Үндсэн хоол)
  - Soups (Шөл)
  - Traditional Mongolian Dishes (Монгол үндэсний хоол)
  - Salads (Салад)
  - Other categories as needed

#### 1.2 Recipe Detail Screen
- **Header**: High-quality recipe image
- **Recipe Information**:
  - Recipe title (Mongolian)
  - Cooking time (Хугацаа)
  - Difficulty level (Хэцүү байдал)
  - Serving size (Хүний тоо)
  - Average rating (Үнэлгээ) with total count
  - Premium badge (if applicable)

- **Ingredients Section**:
  - Each ingredient with icon/image
  - Quantity and unit
  - Clear visual presentation

- **Step-by-Step Instructions**:
  - Numbered steps with detailed Mongolian text
  - Animated images (GIFs) or short videos for each step
  - Progressive loading for performance

- **Nutritional Information**:
  - Calories (Калори)
  - Protein (Уураг)
  - Carbohydrates (Нүүрс ус)
  - Fats (Өөх тос)

- **User Interactions**:
  - Favorite/Unfavorite button (requires login)
  - Star rating (1-5 stars, editable)
  - ~~Shopping list generator~~ (Future feature)

#### 1.3 Video Tutorials
- Text-based instructions
- Video-based tutorials (optional for each recipe)
- Step-by-step photos/GIFs
- Adaptive video quality based on network speed
- Thumbnail-first loading strategy

#### 1.4 Search & Discovery
- Search bar with keyword search
- Filter by:
  - Category
  - Cooking time
  - Difficulty level
  - Free vs Premium
- Recently viewed recipes
- Trending recipes algorithm

#### 1.5 User Profile & Favorites
- **Profile Screen**:
  - User information
  - Active subscription status
  - Favorites list (heart icon)
  - Settings menu
  - Customer service button

- **Favorites**:
  - Only available when logged in
  - Automatic offline download when favorited
  - Remove from favorites option
  - Shows offline badge if downloaded

#### 1.6 Authentication System
- **Registration**:
  - Phone number (required)
  - Email address (required)
  - Password
  - Confirm password
  - Terms of Service & Privacy Policy acceptance

- **Login**:
  - Phone number OR Email (flexible)
  - Password
  - "Forgot Password?" option

- **Password Recovery**:
  - Enter phone number or email
  - Send OTP (One-Time Passcode)
  - Verify OTP
  - Enter new password
  - Confirm password reset

#### 1.7 Premium Pass (Эрх) - One-Time Payment
- **Pass Options** (One-Time Purchase):
  - 1 Month Pass (1 Сарын Эрх): 9,000 MNT - Single payment for 30 days access
  - 3 Months Pass (3 Сарын Эрх): 21,000 MNT - Single payment for 90 days access (save ~25%)
  - 6 Months Pass (6 Сарын Эрх): 36,000 MNT - Single payment for 180 days access (save ~33%)

- **Payment Model**: One-time payment (NOT recurring subscription)
  - User pays once, gets access for specified duration
  - No auto-renewal
  - User must manually purchase new pass after expiration
  - Can purchase new pass at any time (even after expiration)

- **Payment Method: Semi-Automated Bank Transfer (Option 1)**

  **User Payment Flow:**
  1. User selects pass duration from 3 options (one-time payment)
  2. App generates **unique transaction code** 
     - Format: `[USERNAME]-[PLAN]-[TIMESTAMP]`
     - Example: `MUNKH123-1M-20260202154530`
  3. Payment instruction screen displays:
     - Your bank account number
     - Exact amount to transfer (e.g., 9,000 MNT)
     - **Transaction code** (with copy-to-clipboard button)
     - Clear instructions in Mongolian: "Include this code in the transfer description"
  4. User opens their bank app (Khan Bank, TDB, Golomt, etc.)
  5. User transfers money to your account
  6. User pastes transaction code in the transfer description field
  7. User completes the payment with password
  8. User returns to your app
  9. User enters their **Transaction ID** (from bank receipt)
  10. User taps "Submit Payment" button
  11. Status shows: "Pending Verification" (Хүлээгдэж байна)

  **Admin Verification Process:**
  1. Admin Console receives real-time notification of new payment submission
  2. Admin opens "Payment Management" section
  3. Admin sees pending payment with:
     - User name and ID
     - Transaction code
     - Transaction ID entered by user
     - Amount and pass duration
     - Submission timestamp
  4. Admin checks bank account statement (via bank app or online banking)
  5. Admin finds matching transaction by:
     - Transaction code in description
     - Amount matches
     - Transaction ID matches
  6. Admin clicks **"Approve"** button in Admin Console
  7. System automatically:
     - Updates user's `hasActiveSubscription = true`
     - Sets `passType` (1month/3months/6months)
     - Calculates and sets `subscriptionExpiryDate`
     - Changes payment status to "Approved"
     - Sends in-app notification to user
  8. User instantly gains access to premium content

  **If Payment Doesn't Match:**
  - Admin clicks "Reject" with reason
  - User receives notification to contact customer service
  - Admin and user resolve via in-app chat

  **Benefits of This Approach:**
  - Works with ALL Mongolian banks (Khan Bank, TDB, Golomt, State Bank, etc.)
  - No need for complex API integrations initially
  - Transaction code ensures accurate matching
  - Quick verification (admin checks once or twice daily)
  - Can upgrade to automated API later without changing user flow

- **Premium Content Access**:
  - Premium recipes locked behind paywall
  - Clear "Premium" badge on locked recipes
  - Payment wall modal when accessing premium content
  - Instant access upon subscription activation

- **Pass Expiration**:
  - Automatic lockout from premium content when pass expires
  - Clear notification: "Таны эрх дууссан байна" (Your pass has expired)
  - Prompt to purchase new pass (not renewal, but new one-time purchase)
  - No auto-renewal - user must actively purchase again
  - ~~Reminder notifications before expiry~~ (Future feature)

#### 1.8 Offline Mode
- **Offline Functionality**:
  - Favorited recipes automatically downloaded
  - Full recipe content available offline (text, images, videos)
  - Clear offline indicator in UI

- **No Internet State**:
  - Show only downloaded/favorited recipes
  - Display message: "Интернэт холболт алга" (No Internet)
  - Subtitle: "Жор үзэхийн тулд интернэт холболт шаардлагатай" (Please connect to the Internet to see recipes)

#### 1.9 Rating & Reviews
- **Rating System**:
  - 5-star rating (1-5 stars)
  - Display total ratings count
  - Users can rate only when logged in
  - Users can change their rating anytime
  - Average rating displayed on recipe cards and detail screen

#### 1.10 Customer Service
- **In-App Support**:
  - "Customer Service" button in Settings menu
  - Private chat with support team (admin)
  - Users can send text messages
  - Users can attach images (proof of issues, screenshots)
  - Real-time chat interface
  - Connected to Admin Console app

---

### 2. Future Features (Post-Launch)

- **Share Recipes**: Social sharing to WhatsApp, Facebook, etc.
- **Shopping List**: Generate and manage shopping lists from recipes
- **Push Notifications**: New recipe alerts, trending recommendations
- **Automated Payment**: Integrate QPay or MonPay Business API
- **Multiple Languages**: English, Russian (long-term consideration)
- **Video Upload**: More recipe videos
- **Advanced Filters**: Dietary restrictions, cuisine type

---

## 🛠️ Technical Stack

### Mobile App (Flutter/Dart)

#### Frontend Framework
- **Flutter**: Cross-platform development (iOS & Android)
- **Dart**: Programming language
- **Minimum Android Version**: Android 5.0+ (API 21+) - Flutter default support
- **Minimum iOS Version**: iOS 12.0+ - Flutter default support

#### Key Flutter Packages (Recommended)
- **State Management**: `provider` or `riverpod` (for app state)
- **Navigation**: `go_router` (for declarative routing)
- **HTTP Requests**: `http` or `dio` (for API calls)
- **Local Storage**: `shared_preferences` (for user settings, tokens)
- **Offline Database**: `sqflite` or `hive` (for downloaded recipes)
- **Image Caching**: `cached_network_image` (for performance)
- **Video Player**: `video_player` or `chewie` (for tutorial videos)
- **Animations**: `flutter_animate` or custom animations
- **Authentication**: Appwrite SDK for Flutter
- **File Download**: `flutter_downloader` (for offline recipes)
- **Rating**: `flutter_rating_bar` (for star ratings)
- **Shimmer Loading**: `shimmer` (for skeleton screens)
- **Clipboard**: `flutter_clipboard` (for copying transaction codes)

#### UI/UX Design Principles
- **Design Style**: iOS 26 inspired design language
  - Modern navigation bar layout (bottom tab bar with floating elements)
  - Clean, minimal interface with depth through shadows rather than blur
  - Rounded corners and cards
  - Smooth transitions and gestures
  - Material You-like adaptive colors (for Android compatibility)
- **Color Scheme**: Minimal yet expressive, adaptive theming
- **Animations**: Smooth, intuitive, lightweight (iOS-like spring animations)
- **Performance**: Optimized for low-end devices
- **Accessibility**: Clear fonts, proper contrast, readable text sizes
- **Navigation**: iOS 26 style bottom navigation with gesture support

#### Performance Optimization
- **Image Compression**: All images compressed before upload
- **Lazy Loading**: Load content as needed, not all at once
- **Caching Strategy**: 
  - Cache images locally using `cached_network_image`
  - Pre-load trending recipes on app launch
  - Store API responses temporarily
- **Video Optimization**:
  - Adaptive streaming based on network speed
  - Thumbnail-first approach
  - Progressive video loading
  - Limit quality on slow networks
- **Code Splitting**: Lazy load screens and features
- **Widget Optimization**: Use `const` constructors where possible

### Backend (Appwrite)

#### Appwrite Services
- **Database**: Store recipe data, user data, subscriptions
- **Authentication**: 
  - Email/Phone authentication
  - OTP for password reset
  - Session management
- **Storage**: Store recipe images, videos, GIFs
- **Functions**: (Optional) Serverless functions for complex logic
- **Realtime**: For customer service chat feature

#### Database Collections

##### Collection 1: `recipes`
```json
{
  "recipeId": "string (unique)",
  "title": "string (Mongolian)",
  "category": "string (enum: desserts, main_dishes, soups, traditional, salads)",
  "headerImage": "string (URL from Appwrite Storage)",
  "cookingTime": "number (minutes)",
  "difficulty": "string (enum: easy, medium, hard)",
  "servings": "number",
  "isPremium": "boolean",
  "ingredients": [
    {
      "name": "string",
      "quantity": "string",
      "unit": "string",
      "iconUrl": "string (optional)"
    }
  ],
  "steps": [
    {
      "stepNumber": "number",
      "description": "string (Mongolian)",
      "mediaUrl": "string (GIF/video URL, optional)"
    }
  ],
  "nutritionalInfo": {
    "calories": "number",
    "protein": "number (grams)",
    "carbs": "number (grams)",
    "fats": "number (grams)"
  },
  "averageRating": "number (0-5)",
  "totalRatings": "number",
  "viewsCount": "number",
  "createdAt": "datetime (auto-generated by Appwrite)",
  "updatedAt": "datetime (auto-generated by Appwrite)"
}
```

##### Collection 2: `users`
```json
{
  "userId": "string (Appwrite Auth User ID)",
  "phoneNumber": "string (unique)",
  "email": "string (unique)",
  "fullName": "string (optional)",
  "hasActiveSubscription": "boolean",
  "subscriptionType": "string (enum: none, 1month, 3months, 6months)",
  "subscriptionExpiryDate": "datetime (null if no subscription)",
  "favorites": ["array of recipe IDs"],
  "createdAt": "datetime",
  "updatedAt": "datetime"
}
```

##### Collection 3: `ratings`
```json
{
  "ratingId": "string (unique)",
  "userId": "string (reference to users collection)",
  "recipeId": "string (reference to recipes collection)",
  "stars": "number (1-5)",
  "createdAt": "datetime",
  "updatedAt": "datetime"
}
```

##### Collection 4: `payments`
```json
{
  "paymentId": "string (unique)",
  "userId": "string (reference to users collection)",
  "transactionCode": "string (generated by app, e.g., USER123-1M-20260202)",
  "transactionId": "string (entered by user from bank receipt)",
  "amount": "number (MNT)",
  "subscriptionType": "string (enum: 1month, 3months, 6months)",
  "status": "string (enum: pending, approved, rejected)",
  "rejectionReason": "string (optional, if rejected)",
  "submittedAt": "datetime",
  "verifiedAt": "datetime (null if pending)",
  "verifiedBy": "string (admin user ID, null if pending)"
}
```

##### Collection 5: `support_messages`
```json
{
  "messageId": "string (unique)",
  "userId": "string (reference to users collection)",
  "message": "string",
  "imageUrls": ["array of image URLs"],
  "isFromAdmin": "boolean",
  "isRead": "boolean",
  "createdAt": "datetime"
}
```

#### Appwrite Storage Buckets
- **`recipe-images`**: Header images for recipes
- **`recipe-media`**: Step-by-step GIFs and videos
- **`ingredient-icons`**: Ingredient icons
- **`support-attachments`**: User-submitted images for support

---

### Admin Console (Windows Web App)

#### Tech Stack
- **Backend**: Python (Flask or FastAPI)
- **Frontend**: Svelte + Vite
- **Desktop Wrapper**: Electron or PyWebView (to make it feel like native Windows app)
- **Styling**: TailwindCSS + Glassmorphism design

#### Features
1. **Recipe Management**:
   - Add new recipes (with form for all fields)
   - Edit existing recipes
   - Delete recipes
   - Upload images/videos to Appwrite Storage
   - Preview recipe as users see it

2. **User Management**:
   - View all users
   - See user details (email, phone, subscription status)
   - Ban/unban users
   - Search users
   - View user subscription history

3. **Payment Management** (Semi-Automated - Option 1):
   - View all pending payment submissions in real-time
   - For each pending payment, display:
     - User name and email
     - Transaction code (for matching)
     - Transaction ID (entered by user)
     - Amount and subscription plan
     - Submission timestamp
   - **Quick verification workflow**:
     - Check bank account statement (separate window/tab)
     - Match transaction code in bank description
     - Verify amount and transaction ID
     - Click "Approve" button → automatically activates subscription
     - Or click "Reject" button → enter reason → notifies user
   - View payment history (approved/rejected)
   - Filter by status, date, user

4. **Customer Support**:
   - Real-time chat interface
   - View all support conversations
   - Respond to user messages
   - Mark conversations as resolved
   - View attached images

5. **Analytics Dashboard** (Optional for v1):
   - Total users count
   - Active subscriptions count
   - Total revenue
   - Most popular recipes
   - Most searched keywords

6. **Settings**:
   - Contact customer service (for admin's own issues with the system)
   - Admin profile management
   - App configuration
   - Bank account details (for displaying to users)

---

## 🎨 UI/UX Design Guidelines

### Design System

#### Color Palette
- **Primary Colors**: To be defined (consider Mongolian cultural colors)
- **Background**: Light, clean backgrounds for glassmorphism
- **Accent Colors**: For CTAs, premium badges
- **Text**: High contrast for readability

#### Typography
- **Mongolian Font**: Choose readable Mongolian font (e.g., Mongolian Baiti, or custom)
- **Hierarchy**: Clear heading, subheading, body text distinction
- **Size**: Minimum 14px for body text (accessibility)

#### iOS 26 Design Elements
- Elevated cards with subtle shadows (no heavy blur effects)
- Clean white/dark backgrounds with gradient accents
- Rounded corners (16-24px radius)
- Floating action buttons and navigation elements
- Smooth spring animations (iOS-style bounce)
- Gesture-based interactions (swipe, long-press)
- **Performance Note**: Lightweight shadows and simple animations perform well on all devices

#### Animation Guidelines
- **Micro-interactions**: Button presses, swipes, transitions
- **Page Transitions**: Smooth, 200-300ms
- **Loading States**: Shimmer effects, skeleton screens
- **Scroll Animations**: Fade-in effects for recipe cards
- **Keep it lightweight**: Avoid heavy animations on low-end devices

#### Key Screens Layout

##### 1. Home Screen (iOS 26 Style)
- Top: Large title that shrinks on scroll (iOS style)
- Search bar appears on scroll
- Section 1: Trending Recipes (horizontal scroll with cards)
- Section 2: Recommendations (vertical list with elevation)
- Section 3: Categories (grid with rounded cards)
- Bottom: iOS 26 style tab bar
  - Floating/elevated appearance
  - 4 tabs: Home, Search, Favorites, Profile
  - Smooth icon animations on tap
  - Selected tab highlighted with subtle background

##### 2. Recipe Detail Screen
- Scrollable content
- Fixed header with back button and favorite icon
- Hero image at top
- Tabbed sections: Ingredients, Instructions, Nutrition
- Floating action button for "Start Cooking" mode (optional)

##### 3. Profile Screen
- User info card at top
- Subscription status (with expiry date if active)
- Menu items: Favorites, Settings, Customer Service
- Logout button

##### 4. Payment Screen (One-Time Pass Purchase)
- **Step 1: Pass Selection**
  - Three pass option cards (1M, 3M, 6M)
  - Clear "One-Time Payment" label on each card
  - Highlight savings on longer passes
  - Selected pass has accent border and checkmark
  - Note: "No auto-renewal, purchase once for access"

- **Step 2: Payment Instructions**
  - Transaction code displayed prominently (large, bold)
  - Copy button next to transaction code
  - Bank account details card:
    - Bank name
    - Account number
    - Account holder name
    - Amount to transfer
  - Clear numbered instructions in Mongolian:
    1. "Open your bank app"
    2. "Transfer [amount] MNT to this account"
    3. "Paste this code in the description"
    4. "Complete the payment"
    5. "Return here and enter your Transaction ID"

- **Step 3: Transaction ID Entry**
  - Input field for Transaction ID
  - Helper text: "Find this in your bank receipt"
  - Submit button
  - "Payment submitted! We'll verify within 24 hours" confirmation

##### 5. Pending Payment Status Screen
- Shows "Verification in Progress" animation
- Estimated verification time: "Usually within 24 hours"
- Option to contact customer service if urgent

#### Iconography
- Use consistent icon set (e.g., Material Icons, Font Awesome)
- Custom icons for ingredients
- Clear visual language

---

## 🔐 Security & Privacy

### Data Protection
- **Password Hashing**: Handled by Appwrite (bcrypt)
- **HTTPS Only**: All API calls over HTTPS
- **Token Management**: Secure JWT tokens from Appwrite
- **Local Storage Encryption**: Sensitive data encrypted on device
- **Transaction Code Security**: Time-based codes, single-use

### Privacy Policy Requirements
- Data collection disclosure
- How user data is used
- Third-party services (Appwrite, bank services)
- User rights (access, deletion, modification)
- Contact information for privacy concerns

### Terms of Service Requirements
- Usage guidelines
- Payment terms and refund policy (if applicable)
- Content ownership
- Liability limitations
- Dispute resolution

---

## 💰 Monetization Strategy

### One-Time Pass Model
- **Free Tier**: Basic recipes, limited access
- **Premium Pass**: One-time payment for temporary access to exclusive recipes
- **Pricing**: Competitive for Mongolian market
  - Pay once, no recurring charges
  - Choose duration: 1, 3, or 6 months
  - Must repurchase after expiration (no auto-renewal)
- **Value Proposition**: Restaurant-quality dishes, exclusive content, no subscription commitment

### Payment Processing
- **Current Solution**: Semi-automated bank transfer (Option 1)
- **Transaction Code System**: Unique codes to match payments
- **Verification Time**: Target 24 hours or less
- **Future Integration**: QPay or MonPay Business API for full automation

### Revenue Projections
- To be calculated based on:
  - Target user base
  - Conversion rate (free to premium)
  - Average subscription duration
  - Marketing budget

---

## 📱 User Flow Diagrams

### Authentication Flow
```
[App Launch] → Check Auth Status
  ↓
  If Logged In → [Home Screen]
  ↓
  If Not Logged In → [Onboarding/Login Screen]
  ↓
  [Login] or [Register]
  ↓
  [Enter Phone/Email + Password]
  ↓
  [Appwrite Authentication]
  ↓
  [Home Screen]
```

### Recipe Discovery to Viewing Flow
```
[Home Screen] → Browse Trending/Categories
  ↓
  [Tap Recipe Card]
  ↓
  Check if Premium + User has no active subscription
    ↓ Yes → [Payment Wall Modal]
    ↓ No → [Recipe Detail Screen]
  ↓
  [View Ingredients, Steps, Videos]
  ↓
  [Favorite (auto-downloads)] or [Rate Recipe]
```

### Payment Flow (Semi-Automated - Option 1)
```
[Premium Recipe/Paywall] → [Select Subscription Plan]
  ↓
  [Generate Unique Transaction Code]
  ↓
  [Display Payment Instructions Screen]
  ↓
  User opens bank app (external)
  ↓
  User transfers money with transaction code in description
  ↓
  [User returns to app]
  ↓
  [Enter Transaction ID from bank receipt]
  ↓
  [Submit Payment]
  ↓
  [Status: Pending Verification]
  ↓
  [Admin receives notification in Admin Console]
  ↓
  Admin checks bank statement
  ↓
  Admin matches transaction code + amount
  ↓
  Admin clicks "Approve"
  ↓
  [Subscription Activated Instantly]
  ↓
  [User receives notification]
  ↓
  [Access Premium Content]
```

### Offline Experience Flow
```
[User opens app] → Check Internet
  ↓
  No Internet → [Show Offline Mode]
  ↓
  [Display Only Favorited/Downloaded Recipes]
  ↓
  [All other screens show "No Internet" message]
  ↓
  User reconnects → [Sync data with Appwrite]
```

---

## 🚀 Development Phases

### Phase 1: Planning & Design (Current Phase)
**Duration:** 2-3 weeks
- [x] Define app concept and features
- [x] Create production plan document
- [x] Choose payment method (Semi-Automated - Option 1)
- [ ] Finalize app name
- [ ] Design UI mockups (Figma or Adobe XD)
- [ ] Design app icon and branding
- [ ] Create user flow diagrams
- [ ] Define database schema (Appwrite)
- [ ] Write Terms of Service & Privacy Policy

### Phase 2: Backend Setup
**Duration:** 1-2 weeks
- [ ] Set up Appwrite project
- [ ] Create database collections (recipes, users, ratings, payments, support_messages)
- [ ] Configure Appwrite Authentication (email, phone, OTP)
- [ ] Set up Storage buckets
- [ ] Test Appwrite APIs
- [ ] Define API endpoints and test data

### Phase 3: Mobile App Development - Core Features
**Duration:** 6-8 weeks

#### Sprint 1: Authentication & Navigation (Week 1-2)
- [ ] Set up Flutter project structure
- [ ] Implement splash screen
- [ ] Build authentication screens (Login, Register, Forgot Password)
- [ ] Integrate Appwrite Authentication
- [ ] Implement bottom navigation bar
- [ ] Set up routing (go_router)

#### Sprint 2: Recipe Browsing & Home Screen (Week 3-4)
- [ ] Build Home Screen layout
- [ ] Implement recipe card components
- [ ] Fetch recipes from Appwrite
- [ ] Implement Trending Recipes section
- [ ] Implement Categories section
- [ ] Add search functionality
- [ ] Implement caching for images

#### Sprint 3: Recipe Detail Screen (Week 5-6)
- [ ] Build Recipe Detail Screen layout
- [ ] Display recipe header image
- [ ] Render ingredients with icons
- [ ] Render step-by-step instructions
- [ ] Integrate video player for tutorials
- [ ] Implement GIF/short video playback
- [ ] Add nutritional information display
- [ ] Implement premium content lock

#### Sprint 4: Favorites & Offline Mode (Week 7)
- [ ] Implement Favorites feature
- [ ] Auto-download recipes when favorited
- [ ] Set up local database (sqflite/hive)
- [ ] Implement offline mode detection
- [ ] Show offline indicators
- [ ] Test offline functionality

#### Sprint 5: Rating System (Week 8)
- [ ] Build rating UI (star rating)
- [ ] Implement rating submission to Appwrite
- [ ] Allow users to edit their ratings
- [ ] Display average ratings and count
- [ ] Update recipe average rating on new submissions

### Phase 4: Premium Features & Payment (Semi-Automated)
**Duration:** 2-3 weeks
- [ ] Build subscription plan selection screen
- [ ] Implement transaction code generation algorithm
  - Format: `[USERNAME]-[PLAN_CODE]-[TIMESTAMP]`
  - Example: `BOLDBAATAR-1M-20260215143022`
- [ ] Create payment instructions screen with:
  - Large, prominent transaction code display
  - Copy-to-clipboard functionality
  - Bank account details card
  - Numbered instruction list in Mongolian
- [ ] Build transaction ID entry screen
- [ ] Create payment submission flow
- [ ] Implement "Pending Verification" status display
- [ ] Create payment verification backend logic
- [ ] Test payment flow end-to-end with family testers
- [ ] Implement subscription status checking
- [ ] Add premium content access control
- [ ] Test subscription expiration handling

### Phase 5: Profile & Settings
**Duration:** 1-2 weeks
- [ ] Build User Profile screen
- [ ] Display subscription status (active/expired with dates)
- [ ] Implement Settings menu
- [ ] Add password change functionality
- [ ] Implement logout
- [ ] Build Customer Service chat screen
- [ ] Integrate Appwrite Realtime for chat

### Phase 6: Admin Console Development
**Duration:** 4-5 weeks

#### Backend (Python + Flask/FastAPI)
- [ ] Set up Python project
- [ ] Integrate with Appwrite SDK
- [ ] Build API endpoints for recipe CRUD
- [ ] Build API endpoints for user management
- [ ] Build API endpoints for payment verification (approve/reject)
- [ ] Build API for customer support chat
- [ ] Test all APIs

#### Frontend (Svelte + Vite)
- [ ] Set up Svelte project
- [ ] Build login screen for admin
- [ ] Build dashboard layout with glassmorphism
- [ ] Build Recipe Management UI (add/edit/delete)
- [ ] Build User Management UI
- [ ] Build **Payment Management UI** (PRIORITY):
  - Real-time pending payments list
  - Payment detail card showing:
    - Transaction code (highlighted)
    - Transaction ID
    - User info
    - Amount and plan
  - "Approve" and "Reject" buttons
  - Bank statement checking workflow helper
  - Payment history view
- [ ] Build Customer Support chat UI
- [ ] Build Analytics Dashboard (optional)
- [ ] Integrate with backend APIs
- [ ] Test all features

#### Desktop Wrapper
- [ ] Wrap app in Electron or PyWebView
- [ ] Test on Windows
- [ ] Create Windows installer

### Phase 7: UI Polish & Animations
**Duration:** 2 weeks
- [ ] Implement glassmorphism effects
- [ ] Add page transition animations
- [ ] Add micro-interactions (button presses, swipes)
- [ ] Implement shimmer loading states
- [ ] Polish all screens for consistency
- [ ] Optimize performance for low-end devices
- [ ] Test animations on various devices

### Phase 8: Testing & Bug Fixes
**Duration:** 2-3 weeks
- [ ] Internal testing (developer)
- [ ] Family beta testing
- [ ] Fix critical bugs
- [ ] Test on multiple devices (iOS and Android)
- [ ] Test on low-end devices
- [ ] Test offline mode thoroughly
- [ ] **Test payment flow with REAL bank transfers** (critical for Option 1)
  - Test with Khan Bank
  - Test with other major banks
  - Verify transaction code matching works
  - Test admin approval workflow
  - Test rejection workflow
- [ ] Performance testing and optimization
- [ ] Security testing

### Phase 9: App Store Preparation
**Duration:** 1-2 weeks
- [ ] Create app store listing (Google Play)
- [ ] Create app store listing (Apple App Store)
- [ ] Prepare screenshots (5-8 per platform)
- [ ] Write app description (Mongolian)
- [ ] Create promotional video (optional)
- [ ] Set up developer accounts (Google Play, Apple)
- [ ] Submit Terms of Service and Privacy Policy
- [ ] Upload APK/IPA for review
- [ ] Wait for approval

### Phase 10: Launch & Post-Launch
**Duration:** Ongoing
- [ ] Official launch announcement
- [ ] Monitor app performance and crashes (Firebase Crashlytics)
- [ ] Respond to user feedback
- [ ] Fix bugs in production
- [ ] Add new recipes regularly
- [ ] **Monitor payment verification workflow** - optimize admin time
- [ ] Check bank statement daily for new payments
- [ ] Respond to payment-related customer service queries quickly
- [ ] Collect data on payment verification time (aim to improve)
- [ ] Implement future features (shopping list, push notifications, sharing)
- [ ] Consider upgrading to automated payment API when user base grows
- [ ] Marketing and user acquisition

---

## 📊 Success Metrics (KPIs)

### User Acquisition
- Total downloads
- Daily Active Users (DAU)
- Monthly Active Users (MAU)
- User retention rate (Day 1, Day 7, Day 30)

### Engagement
- Average session duration
- Recipes viewed per session
- Search queries per user
- Favorite recipes count per user
- Average rating count per recipe

### Monetization
- Free to Premium conversion rate
- Total paying users
- Monthly Recurring Revenue (MRR)
- Average Revenue Per User (ARPU)
- Subscription renewal rate
- **Payment verification time** (target: <24 hours for Option 1)
- **Payment approval rate** (target: >95%)

### Content Performance
- Most viewed recipes
- Highest rated recipes
- Premium vs Free recipe views
- Category popularity

### Technical
- App crash rate (target: <0.5%)
- Average load time for recipe screen (target: <2 seconds)
- Offline mode usage rate
- Customer support response time

---

## 🐛 Testing Checklist

### Functional Testing
- [ ] User registration works correctly
- [ ] User login with email works
- [ ] User login with phone works
- [ ] Password reset via OTP works
- [ ] Home screen loads recipes
- [ ] Search returns relevant results
- [ ] Recipe detail screen displays all content
- [ ] Video playback works smoothly
- [ ] Favorites feature works (add/remove)
- [ ] Offline mode shows only downloaded recipes
- [ ] Rating submission works
- [ ] **Transaction code generation is unique**
- [ ] **Transaction code can be copied to clipboard**
- [ ] **Payment instructions display correctly**
- [ ] **Transaction ID submission works**
- [ ] **Payment status shows as "Pending"**
- [ ] Premium content is locked without subscription
- [ ] **Admin receives real-time notification of new payments**
- [ ] **Admin can approve payments**
- [ ] **Admin can reject payments with reason**
- [ ] **Subscription activates instantly upon approval**
- [ ] **User receives activation notification**
- [ ] Customer service chat sends/receives messages
- [ ] Admin console can add/edit/delete recipes

### Performance Testing
- [ ] App runs smoothly on Android 5.0+
- [ ] App runs smoothly on iOS 12.0+
- [ ] App performs well on low-end devices
- [ ] Images load quickly (cached)
- [ ] Videos stream without buffering on good connection
- [ ] App handles poor network gracefully
- [ ] Offline mode activates instantly
- [ ] No memory leaks during extended use

### Payment Testing (Critical for Option 1)
- [ ] Test with Khan Bank transfer - verify code matching works
- [ ] Test with TDB transfer - verify code matching works
- [ ] Test with Golomt Bank transfer - verify code matching works
- [ ] Test with State Bank transfer - verify code matching works
- [ ] Test rejection workflow - user receives notification correctly
- [ ] Test expiration - user loses access after expiry date
- [ ] Test renewal - user can purchase again after expiry
- [ ] Test with intentionally wrong transaction ID - admin can catch it
- [ ] Test admin workflow speed - measure time to verify
- [ ] Test multiple pending payments - admin can handle queue

### Security Testing
- [ ] Passwords are not stored in plain text
- [ ] API calls use HTTPS only
- [ ] User tokens expire appropriately
- [ ] Unauthorized users cannot access premium content
- [ ] Transaction codes cannot be reused
- [ ] Payment information is handled securely

### UI/UX Testing
- [ ] All screens are responsive
- [ ] Text is readable (proper size and contrast)
- [ ] Animations are smooth (60 FPS)
- [ ] Glassmorphism effects look good
- [ ] Loading states are clear
- [ ] Error messages are user-friendly (in Mongolian)
- [ ] Navigation is intuitive
- [ ] Payment instructions are crystal clear
- [ ] Transaction code is easy to copy

---

## 📝 Launch Checklist

### Pre-Launch
- [ ] App fully tested and bug-free
- [ ] Admin console ready and tested
- [ ] At least 20-30 recipes uploaded (mix of free and premium)
- [ ] Terms of Service finalized
- [ ] Privacy Policy finalized
- [ ] App name finalized
- [ ] App icon created
- [ ] Screenshots prepared (5-8 per platform)
- [ ] App store descriptions written
- [ ] **Bank account ready for receiving payments**
- [ ] **Admin trained on payment verification workflow**
- [ ] **Test payment completed successfully end-to-end**
- [ ] Customer support workflow established

### App Store Submissions
- [ ] Google Play Developer account created ($25 one-time)
- [ ] Apple Developer account created ($99/year)
- [ ] APK built and signed (Android)
- [ ] IPA built and signed (iOS)
- [ ] Submitted to Google Play for review
- [ ] Submitted to Apple App Store for review
- [ ] Address any review feedback
- [ ] Apps approved and live

### Marketing
- [ ] Create social media accounts (Facebook, Instagram)
- [ ] Prepare launch announcement posts
- [ ] Reach out to food bloggers/influencers
- [ ] Share with friends and family
- [ ] Post in Mongolian cooking groups/forums
- [ ] Consider paid advertising (Facebook Ads)

### Post-Launch
- [ ] Monitor app reviews daily
- [ ] Respond to user feedback
- [ ] **Check bank statement at least twice daily** for new payments
- [ ] **Verify payments within 24 hours**
- [ ] Fix critical bugs immediately
- [ ] Add new recipes weekly
- [ ] Engage with users on social media
- [ ] Collect user suggestions for improvements
- [ ] Monitor payment-related support tickets
- [ ] Track payment verification time - optimize process
- [ ] Plan next feature releases

---

## 💡 Future Payment Upgrade Path

### When to Upgrade from Semi-Automated (Option 1)

Consider upgrading to automated payment when:
- You have 500+ active subscribers
- Payment verification becomes time-consuming (>2 hours/day)
- Users request faster activation
- You can afford developer time for integration

### Upgrade Option A: Bank API Integration
**Banks with APIs:** Khan Bank, TDB Bank (Business accounts)

**Implementation:**
1. Apply for Business API access from bank
2. Get API credentials
3. Build background service that:
   - Fetches transactions every 10-15 minutes
   - Matches transaction descriptions with pending codes
   - Auto-approves matching payments
   - Admin only verifies mismatches
4. Keep same user flow - transparent upgrade
5. Result: Instant activation (within 15 minutes)

### Upgrade Option B: QPay/MonPay Integration
**Recommended for full automation**

**Implementation:**
1. Register for QPay or MonPay Business account
2. Integrate their SDK into Flutter app
3. User flow changes to:
   - Select plan → Generate QR code or payment link
   - User scans with any banking app
   - Payment completes → Instant webhook callback
   - Subscription activates automatically
4. Result: Instant activation (real-time)

**Benefits:**
- Works with ALL banks
- User never leaves the app
- Instant activation
- No admin verification needed
- Better user experience

**Costs:**
- Transaction fees: ~1-2%
- Monthly service fee: varies

---

## 💰 Cost Estimates

### One-Time Costs
- Google Play Developer Account: $25 (one-time)
- Apple Developer Account: $99/year
- App icon/branding design: $0-100 (DIY or hire)
- Initial recipe content creation: Time investment
- Admin Console development: Time investment

### Recurring Costs
- Appwrite Cloud (if using cloud):
  - Free tier: 0-75,000 users (sufficient initially)
  - Pro tier: ~$15-50/month (if needed later)
- Self-hosted Appwrite: Server costs ~$5-20/month (DigitalOcean, AWS)
- Domain name (optional): ~$10/year
- Marketing budget: Variable (social media ads, influencers)
- **Payment processing: Free (Option 1) or 1-2% (if upgrade to QPay)**

### Revenue Potential (Example)
- 1,000 users with 10% conversion = 100 paying users
- Average subscription value: ~27,000 MNT (assuming mix of 1M/3M/6M plans)
- Quarterly revenue (assuming 3-month average): ~2,700,000 MNT
- After app store fees (30%): ~1,890,000 MNT
- **With Option 1 payment: No additional fees**
- **With QPay (if upgraded): -2% = 1,852,200 MNT**

---

## 🆘 Risk Management

### Technical Risks
| Risk | Impact | Mitigation |
|------|--------|------------|
| Appwrite downtime | High | Implement proper error handling, consider backup solutions |
| Poor performance on low-end devices | High | Rigorous testing, optimization, fallback designs |
| Video streaming issues | Medium | Adaptive streaming, compression, thumbnail fallbacks |
| **Payment verification delays (Option 1)** | **Medium** | **Check bank daily, set user expectations (24h), upgrade to API if needed** |
| **Bank statement not showing transaction codes** | **Medium** | **Test with real transfers during beta, adjust code format if needed** |

### Business Risks
| Risk | Impact | Mitigation |
|------|--------|------------|
| Low user adoption | High | Marketing, referral program, free content quality |
| **Payment fraud** | **Medium** | **Transaction code matching, verify transaction ID, manual check by admin** |
| Competition from other apps | Medium | Unique content, Mongolian focus, superior UX |
| Recipe content shortage | High | Partner with aunt, community contributions (moderated) |
| **Admin unavailable for payment verification** | **Low** | **Set clear verification hours, auto-respond with expected wait time** |

### Legal Risks
| Risk | Impact | Mitigation |
|------|--------|------------|
| App store rejection | High | Follow all guidelines, proper T&C and Privacy Policy |
| Copyright issues with recipes | Medium | Use original recipes or properly attributed content |
| User data privacy violations | High | Comply with data protection laws, clear privacy policy |

---

## 📞 Contact & Support

### Development Team
- **Lead Developer:** [Your Name]
- **Content Provider:** [Aunt's Name]
- **Beta Testers:** Family members

### Support Channels
- **In-App Support:** Customer service chat
- **Email:** [Your email]
- **Social Media:** [Facebook/Instagram pages once created]

---

## 📚 Appendix

### A. Transaction Code Generation Algorithm

**Format:** `[USERNAME]-[PLAN_CODE]-[TIMESTAMP]`

**Example Implementation (Dart):**
```dart
String generateTransactionCode(String username, String planType) {
  // Sanitize username (remove spaces, special chars, limit length)
  String cleanUsername = username
      .replaceAll(RegExp(r'[^a-zA-Z0-9]'), '')
      .substring(0, min(username.length, 10))
      .toUpperCase();
  
  // Plan code
  String planCode = {
    '1month': '1M',
    '3months': '3M',
    '6months': '6M',
  }[planType] ?? '1M';
  
  // Timestamp (YYYYMMDDHHmmss)
  String timestamp = DateTime.now()
      .toIso8601String()
      .replaceAll(RegExp(r'[-:T.]'), '')
      .substring(0, 14);
  
  return '$cleanUsername-$planCode-$timestamp';
}

// Example output: "BOLDBAATAR-3M-20260215143022"
```

**Why This Format Works:**
- **Unique**: Timestamp ensures no duplicates
- **Readable**: Admin can understand at a glance
- **Short enough**: Fits in bank description field
- **Matchable**: Easy to search in bank statement

### B. Admin Payment Verification Workflow (Detailed)

**Daily Routine (10-15 minutes, 2x per day):**

1. **Morning Check (9-10 AM):**
   - Open Admin Console
   - Check "Pending Payments" section
   - Note all pending transaction codes
   - Open bank app/website
   - Check transaction history for past 24 hours
   - For each bank transaction:
     - Look for transaction code in description
     - Match with pending payment in Admin Console
     - Verify amount matches subscription plan
     - Click "Approve"
   - For unmatched transactions (no code):
     - Ignore or investigate if amount matches

2. **Evening Check (6-7 PM):**
   - Repeat same process
   - Respond to any customer service inquiries about payments

**Tips for Efficiency:**
- Sort bank transactions by date (newest first)
- Use Ctrl+F to search for transaction codes in bank statement
- Keep a checklist of verified codes
- Batch approve multiple payments at once if possible

**When You Can't Check:**
- Set up auto-reply in customer service: "Payment verification happens 2x daily (morning and evening). Your subscription will activate within 24 hours."
- Consider delegating to trusted family member with admin access

### C. Customer Service Response Templates (Mongolian)

**Payment Pending:**
```
Сайн байна уу! Таны төлбөрийг хүлээн авлаа. 24 цагийн дотор баталгаажуулах болно. Баярлалаа!

(Hello! We received your payment. We'll verify it within 24 hours. Thank you!)
```

**Payment Approved:**
```
Таны эрх идэвхжлээ! Одоо бүх premium жорыг үзэх боломжтой. Сайхан хоол хийцгээе!

(Your subscription is now active! You can now view all premium recipes. Happy cooking!)
```

**Payment Rejected (wrong amount):**
```
Уучлаарай, таны шилжүүлсэн дүн буруу байна. [Plan name]-д зориулж [Amount] MNT шилжүүлэх хэрэгтэй. Дахин оролдоно уу эсвэл холбоо барина уу.

(Sorry, the amount you transferred is incorrect. For [Plan name], you need to transfer [Amount] MNT. Please try again or contact us.)
```

### D. Recommended Development Tools

**Design:**
- Figma (UI/UX mockups)
- Adobe Photoshop/Illustrator (graphics, icons)
- Canva (social media graphics)

**Development:**
- VS Code (code editor)
- Android Studio (Android emulator)
- Xcode (iOS simulator - Mac only)
- Postman (API testing)
- Git & GitHub (version control)

**Testing:**
- Firebase Test Lab (automated testing)
- BrowserStack (device testing)
- Firebase Crashlytics (crash reporting)

**Project Management:**
- Trello or Notion (task tracking)
- Figma (design collaboration)
- GitHub Projects (development tracking)

---

## ✅ Next Steps

1. **Finalize App Name** - Choose a catchy Mongolian name
2. **Create UI Mockups** - Design all key screens in Figma (focus on payment screens)
3. **Set Up Development Environment** - Install Flutter, Android Studio, Xcode
4. **Create Appwrite Account** - Set up project and database
5. **Test Bank Transfer** - Do a test transfer with transaction code in description
6. **Start Phase 2** - Begin backend setup
7. **Prepare Recipe Content** - Work with aunt to gather initial recipes
8. **Write Legal Documents** - Draft Terms of Service and Privacy Policy

---

**Document Version:** 1.0 (Semi-Automated Payment - Option 1)  
**Status:** Ready for Development  
**Payment Method:** Semi-Automated Bank Transfer with Admin Verification  
**Next Review Date:** After Phase 2 completion

---

*This plan is a living document and will be updated as the project progresses and requirements evolve.*