const { onDocumentCreated, onDocumentUpdated } = require('firebase-functions/v2/firestore');
const admin = require('firebase-admin');
admin.initializeApp();

// Handle new match notifications
exports.onNewMatch = onDocumentCreated('matches/{matchId}', async (event) => {
    const matchData = event.data.data();
    const { users } = matchData;
    const matchId = event.params.matchId;

    try {
        // Update match with initial activity timestamp
        await admin.firestore()
            .collection('matches')
            .doc(matchId)
            .update({
                lastActivity: admin.firestore.FieldValue.serverTimestamp(),
                lastActivityType: 'match',
                viewed: {
                    [users[0]]: null,
                    [users[1]]: null
                }
            });

        // Get both users' data
        const [user1Doc, user2Doc] = await Promise.all([
            admin.firestore().collection('users').doc(users[0]).get(),
            admin.firestore().collection('users').doc(users[1]).get()
        ]);

        const user1Data = user1Doc.data();
        const user2Data = user2Doc.data();

        const notifications = [];

        // Prepare notification for user1
        if (user1Data.fcmToken) {
            notifications.push({
                token: user1Data.fcmToken,
                notification: {
                    title: "New Match! 🎉",
                    body: `You matched with ${user2Data.firstName}!`
                },
                data: {
                    type: 'match',
                    matchId: event.params.matchId,
                    otherUserId: users[1]
                }
            });
        }

        // Prepare notification for user2
        if (user2Data.fcmToken) {
            notifications.push({
                token: user2Data.fcmToken,
                notification: {
                    title: "New Match! 🎉",
                    body: `You matched with ${user1Data.firstName}!`
                },
                data: {
                    type: 'match',
                    matchId: event.params.matchId,
                    otherUserId: users[0]
                }
            });
        }

        // Send all notifications
        await Promise.all(
            notifications.map(msg =>
                admin.messaging().send(msg).catch(error => {
                    console.error('Error sending match notification:', error);
                })
            )
        );

    } catch (error) {
        console.error('Error in onNewMatch function:', error);
    }
});

// Handle new message notifications
exports.onNewMessage = onDocumentCreated('matches/{matchId}/messages/{messageId}', async (event) => {
    const messageData = event.data.data();
    const { senderId, text } = messageData;
    const { matchId } = event.params;

    try {
        // Update match's lastActivity
        await admin.firestore()
            .collection('matches')
            .doc(matchId)
            .update({
                lastActivity: admin.firestore.FieldValue.serverTimestamp(),
                lastActivityType: 'message'
            });

        // Get match data to get both user IDs
        const matchDoc = await admin.firestore()
            .collection('matches')
            .doc(matchId)
            .get();

        const matchData = matchDoc.data();
        const recipientId = matchData.users.find(id => id !== senderId);

        // Get sender and recipient data
        const [senderDoc, recipientDoc] = await Promise.all([
            admin.firestore().collection('users').doc(senderId).get(),
            admin.firestore().collection('users').doc(recipientId).get()
        ]);

        const senderData = senderDoc.data();
        const recipientData = recipientDoc.data();

        // Only send if recipient has an FCM token
        if (recipientData.fcmToken) {
            const message = {
                token: recipientData.fcmToken,
                notification: {
                    title: `Message from ${senderData.firstName}`,
                    body: text.length > 100 ? `${text.substring(0, 97)}...` : text
                },
                data: {
                    type: 'message',
                    matchId,
                    messageId: event.params.messageId,
                    senderId
                },
                apns: {
                    payload: {
                        aps: {
                            'mutable-content': 1,
                            'content-available': 1
                        }
                    }
                }
            };

            await admin.messaging().send(message);
        }

    } catch (error) {
        console.error('Error in onNewMessage function:', error);
    }
});

// Handle unmatch notifications
exports.onUnmatch = onDocumentCreated('users/{userId}/unmatches/{unmatchId}', async (event) => {
    const unmatchedUserId = event.params.unmatchId;

    try {
        // Get unmatched user's data
        const unmatchedUserDoc = await admin.firestore()
            .collection('users')
            .doc(unmatchedUserId)
            .get();

        const unmatchedUserData = unmatchedUserDoc.data();

        if (unmatchedUserData?.fcmToken) {
            const message = {
                token: unmatchedUserData.fcmToken,
                notification: {
                    title: "Someone Unmatched You",
                    body: "You can now rate the quality of the conversation you had with this user"
                },
                data: {
                    type: 'unmatch'
                }
            };

            await admin.messaging().send(message);
        }

    } catch (error) {
        console.error('Error in onUnmatch function:', error);
    }
});

// Handle social and date request confirmations
exports.onMatchUpdate = onDocumentUpdated('matches/{matchId}', async (event) => {
    const newData = event.data.after.data();
    const oldData = event.data.before.data();
    const { users } = newData;
    const matchId = event.params.matchId;

    try {
        // Check for social request confirmation
        if (newData.socialRequestConfirmed && !oldData.socialRequestConfirmed) {
            // Update activity timestamp
            await admin.firestore()
                .collection('matches')
                .doc(matchId)
                .update({
                    lastActivity: admin.firestore.FieldValue.serverTimestamp(),
                    lastActivityType: 'social'
                });

            // Create system message
            await admin.firestore()
                .collection('matches')
                .doc(matchId)
                .collection('messages')
                .add({
                    text: "🎉 Social media request confirmed! You can both now share social media!",
                    timestamp: admin.firestore.FieldValue.serverTimestamp(),
                    senderId: 'system'
                });

            // Get both users' data for notifications
            const [user1Doc, user2Doc] = await Promise.all([
                admin.firestore().collection('users').doc(users[0]).get(),
                admin.firestore().collection('users').doc(users[1]).get()
            ]);

            const notifications = [];

            // Add notifications for both users
            [user1Doc, user2Doc].forEach(userDoc => {
                const userData = userDoc.data();
                if (userData.fcmToken) {
                    notifications.push({
                        token: userData.fcmToken,
                        notification: {
                            title: "Social Request Confirmed! 🎉",
                            body: "Both you and your match want to share social media! Open the app to proceed."
                        },
                        data: {
                            type: 'socialConfirm',
                            matchId: event.params.matchId
                        }
                    });
                }
            });

            // Send all notifications
            await Promise.all(
                notifications.map(msg =>
                    admin.messaging().send(msg).catch(error => {
                        console.error('Error sending social confirmation notification:', error);
                    })
                )
            );
        }

        // Check for date request confirmation
        if (newData.dateRequestConfirmed && !oldData.dateRequestConfirmed) {
            // Update activity timestamp
            await admin.firestore()
                .collection('matches')
                .doc(matchId)
                .update({
                    lastActivity: admin.firestore.FieldValue.serverTimestamp(),
                    lastActivityType: 'date'
                });

            // Create system message
            await admin.firestore()
                .collection('matches')
                .doc(matchId)
                .collection('messages')
                .add({
                    text: "💫 Date request confirmed! You can both now plan to meet!",
                    timestamp: admin.firestore.FieldValue.serverTimestamp(),
                    senderId: 'system'
                });

            // Get both users' data for notifications
            const [user1Doc, user2Doc] = await Promise.all([
                admin.firestore().collection('users').doc(users[0]).get(),
                admin.firestore().collection('users').doc(users[1]).get()
            ]);

            const notifications = [];

            // Add notifications for both users
            [user1Doc, user2Doc].forEach(userDoc => {
                const userData = userDoc.data();
                if (userData.fcmToken) {
                    notifications.push({
                        token: userData.fcmToken,
                        notification: {
                            title: "Date Request Confirmed! 💫",
                            body: "Both you and your match want to meet! Open the app to proceed."
                        },
                        data: {
                            type: 'dateConfirm',
                            matchId: event.params.matchId
                        }
                    });
                }
            });

            // Send all notifications
            await Promise.all(
                notifications.map(msg =>
                    admin.messaging().send(msg).catch(error => {
                        console.error('Error sending date confirmation notification:', error);
                    })
                )
            );
        }

    } catch (error) {
        console.error('Error in onMatchUpdate function:', error);
    }
});
