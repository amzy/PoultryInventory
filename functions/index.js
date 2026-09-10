const { onDocumentCreated } = require('firebase-functions/v2/firestore');
const { onSchedule } = require('firebase-functions/v2/scheduler');
const { setGlobalOptions } = require('firebase-functions/v2');
const admin = require('firebase-admin');
const { DateTime } = require('luxon');

admin.initializeApp();
setGlobalOptions({ region: 'asia-south2', maxInstances: 5 });
const db = admin.firestore();
const messaging = admin.messaging();

function interpolate(text, values) {
  return (text || '').replace(/\{(memberName|flockName|breedName|date)\}/g, (_, k) => values[k] || '');
}

async function tokensFor(uid) {
  const snap = await db.collection('users').doc(uid).collection('devices').get();
  return snap.docs.map(d => d.data().token).filter(Boolean);
}

async function sendToMember(uid, language, payload, values) {
  const tokens = await tokensFor(uid);
  if (!tokens.length) return 0;
  const title = interpolate(language === 'hi' ? payload.titleHi : payload.titleEn, values);
  const body = interpolate(language === 'hi' ? payload.bodyHi : payload.bodyEn, values);
  const response = await messaging.sendEachForMulticast({ tokens, notification: { title, body }, data: { type: payload.type || 'poultry_notification', flockId: values.flockId || '' } });
  const invalid = [];
  response.responses.forEach((r, i) => { if (!r.success && ['messaging/registration-token-not-registered','messaging/invalid-registration-token'].includes(r.error?.code)) invalid.push(tokens[i]); });
  if (invalid.length) {
    const batch = db.batch();
    const snap = await db.collection('users').doc(uid).collection('devices').get();
    snap.docs.filter(d => invalid.includes(d.data().token)).forEach(d => batch.delete(d.ref));
    await batch.commit();
  }
  return response.successCount;
}

exports.sendFlockNotification = onDocumentCreated('flocks/{flockId}/notification_requests/{requestId}', async event => {
  const request = event.data?.data();
  if (!request || request.status !== 'pending') return;
  const flockId = event.params.flockId;
  const flockSnap = await db.doc(`flocks/${flockId}`).get();
  if (!flockSnap.exists) return;
  const flock = flockSnap.data();
  const members = request.memberUid
    ? [await db.doc(`flocks/${flockId}/members/${request.memberUid}`).get()]
    : (await db.collection(`flocks/${flockId}/members`).get()).docs;
  let sent = 0;
  for (const m of members) {
    if (!m.exists) continue;
    const md = m.data();
    sent += await sendToMember(m.id, md.notificationLanguage === 'hi' ? 'hi' : 'en', request, {
      memberName: md.displayName || md.email || 'Member', flockName: flock.name || 'Flock', breedName: flock.breedName || '', date: DateTime.now().toFormat('dd MMM yyyy'), flockId
    });
  }
  await event.data.ref.update({ status: 'sent', sent, sentAt: admin.firestore.FieldValue.serverTimestamp() });
});

exports.dailyReportReminder = onSchedule({ schedule: 'every 15 minutes', timeZone: 'Asia/Kolkata' }, async () => {
  const flocks = await db.collection('flocks').where('endDate', '==', null).get();
  const now = DateTime.now().setZone('Asia/Kolkata');
  const dateKey = now.toFormat('yyyy-MM-dd');
  for (const flockDoc of flocks.docs) {
    const flock = flockDoc.data();
    const settingsDoc = await flockDoc.ref.collection('notification_settings').doc('config').get();
    const settings = settingsDoc.exists ? settingsDoc.data() : {};
    if (settings.enabled === false || settings.dailyReportReminder === false) continue;
    const h = Number(settings.reminderHour ?? 20), min = Number(settings.reminderMinute ?? 0);
    const currentMinute = now.hour * 60 + now.minute;
    if (Math.abs(currentMinute - (h * 60 + min)) > 7) continue;
    const log = await flockDoc.ref.collection('daily_logs').doc(dateKey).get();
    if (log.exists) continue;
    const templateDoc = await flockDoc.ref.collection('notification_templates').doc('daily_report_reminder').get();
    const template = templateDoc.exists ? templateDoc.data() : {
      titleEn:'Daily Report Reminder', titleHi:'दैनिक रिपोर्ट रिमाइंडर',
      bodyEn:"Today's daily report for {flockName} has not been submitted.", bodyHi:'{flockName} की आज की दैनिक रिपोर्ट अभी दर्ज नहीं की गई है।'
    };
    const members = await flockDoc.ref.collection('members').get();
    for (const m of members.docs) {
      const md = m.data();
      if (md.receiveDailyReminder === false) continue;
      await sendToMember(m.id, md.notificationLanguage === 'hi' ? 'hi' : 'en', { ...template, type:'daily_report_reminder' }, { memberName:md.displayName||md.email||'Member', flockName:flock.name||'Flock', breedName:flock.breedName||'', date:now.toFormat('dd MMM yyyy'), flockId:flockDoc.id });
    }
  }
});
