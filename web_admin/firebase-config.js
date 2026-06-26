// Firebase Web Configuration using SDK v8 (Compat)
const firebaseConfig = {
  apiKey: "AIzaSyCsfpkMyay8pQR2UykgZi7QZ_bRfNxt_uo",
  authDomain: "sicce-2026.firebaseapp.com",
  projectId: "sicce-2026",
  storageBucket: "sicce-2026.firebasestorage.app",
  messagingSenderId: "410266396789",
  appId: "1:410266396789:web:5317fb12e4f01cae82489c" // Standard Web App ID format
};

// Initialize Firebase
if (!firebase.apps.length) {
  firebase.initializeApp(firebaseConfig);
}

const db = firebase.firestore();
const auth = firebase.auth();
