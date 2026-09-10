/* Firebase Cloud Messaging service worker for Poultry Inventory. */
importScripts('https://www.gstatic.com/firebasejs/11.0.2/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/11.0.2/firebase-messaging-compat.js');
firebase.initializeApp({
  apiKey: 'AIzaSyCeOx2tor6BHvENN-sgbYuwHBEmncLm7QA',
  authDomain: 'poultryinventory.firebaseapp.com',
  projectId: 'poultryinventory',
  storageBucket: 'poultryinventory.firebasestorage.app',
  messagingSenderId: '395473159192',
  appId: '1:395473159192:web:c5655ee975a4b6e36fef6d'
});
firebase.messaging();
