/**
 * Import function triggers from their respective submodules:
 *
 * const {onCall} = require("firebase-functions/v2/https");
 * const {onDocumentWritten} = require("firebase-functions/v2/firestore");
 *
 * See a full list of supported triggers at https://firebase.google.com/docs/functions
 */

const {onRequest} = require("firebase-functions/v2/https");
const logger = require("firebase-functions/logger");


const functions = require("firebase-functions");
const admin = require("firebase-admin");

admin.initializeApp();

exports.sendMeetingNotification = functions.https.onCall(async (data, context) => {
  const fcmToken = data.token;
  const title = data.title;
  const body = data.body;

  const message = {
    token: fcmToken,
    notification: {
      title: title,
      body: body,
    },
    android: {
      priority: "high",
    },
  };

  try {
    const response = await admin.messaging().send(message);
    return { success: true, response };
  } catch (error) {
    console.error("❌ Error sending FCM:", error);
    return { success: false, error: error.message };
  }
});
