// Import the Firebase scripts
importScripts("https://www.gstatic.com/firebasejs/9.23.0/firebase-app-compat.js");
importScripts("https://www.gstatic.com/firebasejs/9.23.0/firebase-messaging-compat.js");

// Initialize Firebase in the service worker
firebase.initializeApp({
  apiKey: "AIzaSyAKUWGQgBTf1OBXqLlBQ0ZiGnk-GrJa3FU",
  authDomain: "ell-tall-market.firebaseapp.com",
  projectId: "ell-tall-market",
  storageBucket: "ell-tall-market.firebasestorage.app",
  messagingSenderId: "941471556278",
  appId: "1:941471556278:web:1644f2f9c839ade308fc17"
});

// Retrieve an instance of Firebase Messaging so that it can handle background messages.
const messaging = firebase.messaging();

messaging.onBackgroundMessage((payload) => {
  console.log('[firebase-messaging-sw.js] Received background message ', payload);
  const notificationTitle = payload.notification.title || 'سوق التل';
  const notificationOptions = {
    body: payload.notification.body || '',
    icon: '/favicon.png',
  };

  self.registration.showNotification(notificationTitle, notificationOptions);
});
