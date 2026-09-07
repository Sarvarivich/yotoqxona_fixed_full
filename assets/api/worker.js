const admin = require('firebase-admin');
const mysql = require('mysql2/promise');
const fs = require('fs');

const SERVICE_ACCOUNT_PATH =
    process.env.FIREBASE_SERVICE_ACCOUNT_JSON ||
    'C:\\firebase-key\\yotoqxona-fe7ab-firebase-adminsdk-fbsvc-e32d5a9610.json';

const MYSQL_CONFIG = {
    host: process.env.MYSQL_HOST || '127.0.0.1',
    port: Number(process.env.MYSQL_PORT || 3306),
    database: process.env.MYSQL_DATABASE || 'yotoqxona',
    user: process.env.MYSQL_USER || 'root',
    password: process.env.MYSQL_PASSWORD || ''
};

const POLL_INTERVAL_MS = 30 * 1000;
const MAX_ATTEMPTS = 10;
const BATCH_SIZE = 50;


/*
|--------------------------------------------------------------------------
| Firebase
|--------------------------------------------------------------------------
*/

function initFirebase() {
    if (!fs.existsSync(SERVICE_ACCOUNT_PATH)) {
        throw new Error(
            `Firebase Service Account topilmadi: ${SERVICE_ACCOUNT_PATH}`
        );
    }

    const serviceAccount = JSON.parse(
        fs.readFileSync(SERVICE_ACCOUNT_PATH, 'utf8')
    );

    if (!admin.apps.length) {
        admin.initializeApp({
            credential: admin.credential.cert(serviceAccount)
        });
    }

    return admin.firestore();
}


/*
|--------------------------------------------------------------------------
| MySQL
|--------------------------------------------------------------------------
*/

async function createMySQLConnection() {
    return mysql.createConnection(MYSQL_CONFIG);
}


/*
|--------------------------------------------------------------------------
| Firebase status
|--------------------------------------------------------------------------
*/

async function setFirebaseStatus(
    conn,
    status,
    errorMessage = null
) {
    await conn.execute(
        `
        UPDATE sync_state
        SET
            firebase_status = ?,
            last_attempt = NOW(),
            last_error = ?,
            pending_count = (
                SELECT COUNT(*)
                FROM sync_queue
                WHERE status IN ('pending', 'processing', 'failed')
            )
        WHERE id = 1
        `,
        [status, errorMessage]
    );
}


/*
|--------------------------------------------------------------------------
| Successful Firebase sync
|--------------------------------------------------------------------------
*/

async function markFirebaseSuccess(conn) {
    await conn.execute(
        `
        UPDATE sync_state
        SET
            firebase_status = 'online',
            last_successful_sync = NOW(),
            last_attempt = NOW(),
            last_error = NULL,
            pending_count = (
                SELECT COUNT(*)
                FROM sync_queue
                WHERE status IN ('pending', 'processing', 'failed')
            )
        WHERE id = 1
        `
    );
}


/*
|--------------------------------------------------------------------------
| Get pending queue
|--------------------------------------------------------------------------
*/

async function getPendingQueue(conn) {
    const [rows] = await conn.execute(
        `
        SELECT
            id,
            collection_name,
            document_id,
            operation,
            data_json,
            status,
            attempts,
            error_message,
            created_at
        FROM sync_queue
        WHERE
            (
                status = 'pending'
                OR
                (
                    status = 'failed'
                    AND attempts < ?
                )
            )
        ORDER BY id ASC
        LIMIT ?
        `,
        [MAX_ATTEMPTS, BATCH_SIZE]
    );

    return rows;
}


/*
|--------------------------------------------------------------------------
| Mark queue item as processing
|--------------------------------------------------------------------------
*/

async function markProcessing(conn, queueId) {
    await conn.execute(
        `
        UPDATE sync_queue
        SET
            status = 'processing',
            attempts = attempts + 1,
            error_message = NULL
        WHERE id = ?
        `,
        [queueId]
    );
}


/*
|--------------------------------------------------------------------------
| Mark queue item as synced
|--------------------------------------------------------------------------
*/

async function markSynced(conn, queueId) {
    await conn.execute(
        `
        UPDATE sync_queue
        SET
            status = 'synced',
            processed_at = NOW(),
            error_message = NULL
        WHERE id = ?
        `,
        [queueId]
    );
}


/*
|--------------------------------------------------------------------------
| Mark queue item as failed
|--------------------------------------------------------------------------
*/

async function markFailed(
    conn,
    queueId,
    errorMessage
) {
    await conn.execute(
        `
        UPDATE sync_queue
        SET
            status = CASE
                WHEN attempts >= ? THEN 'failed'
                ELSE 'pending'
            END,
            error_message = ?
        WHERE id = ?
        `,
        [
            MAX_ATTEMPTS,
            errorMessage.substring(0, 2000),
            queueId
        ]
    );
}


/*
|--------------------------------------------------------------------------
| Mark change history as synced
|--------------------------------------------------------------------------
*/

async function markHistorySynced(
    conn,
    collectionName,
    documentId,
    operation
) {
    await conn.execute(
        `
        UPDATE change_history
        SET
            sync_status = 'synced'
        WHERE
            collection_name = ?
            AND document_id = ?
            AND sync_status = 'pending'
            AND change_type = ?
        ORDER BY id DESC
        LIMIT 1
        `,
        [
            collectionName,
            documentId,
            operation
        ]
    );
}


/*
|--------------------------------------------------------------------------
| Firebase CREATE / UPDATE / DELETE
|--------------------------------------------------------------------------
*/

async function sendToFirebase(db, item) {

    const collectionRef =
        db.collection(item.collection_name);

    const documentRef =
        collectionRef.doc(item.document_id);


    /*
    |--------------------------------------------------------------------------
    | CREATE
    |--------------------------------------------------------------------------
    */

    if (item.operation === 'create') {

        let data = {};

        if (item.data_json) {
            data = JSON.parse(item.data_json);
        }

        await documentRef.set(data);

        return;
    }


    /*
    |--------------------------------------------------------------------------
    | UPDATE
    |--------------------------------------------------------------------------
    */

    if (item.operation === 'update') {

        let data = {};

        if (item.data_json) {
            data = JSON.parse(item.data_json);
        }

        /*
        | set() ishlatiladi.
        | Bu Firebase documentini to'liq MySQLdagi holatga moslaydi.
        */

        await documentRef.set(data);

        return;
    }


    /*
    |--------------------------------------------------------------------------
    | DELETE
    |--------------------------------------------------------------------------
    */

    if (item.operation === 'delete') {

        await documentRef.delete();

        return;
    }


    throw new Error(
        `Noma'lum operation: ${item.operation}`
    );
}


/*
|--------------------------------------------------------------------------
| Process one queue item
|--------------------------------------------------------------------------
*/

async function processItem(db, conn, item) {

    console.log('');
    console.log('------------------------------------------------');
    console.log(`Queue ID:       ${item.id}`);
    console.log(`Collection:     ${item.collection_name}`);
    console.log(`Document:       ${item.document_id}`);
    console.log(`Operation:      ${item.operation}`);
    console.log(`Attempt:        ${item.attempts + 1}`);
    console.log('------------------------------------------------');


    await markProcessing(conn, item.id);


    try {

        await sendToFirebase(db, item);


        await markSynced(
            conn,
            item.id
        );


        await markHistorySynced(
            conn,
            item.collection_name,
            item.document_id,
            item.operation
        );


        await markFirebaseSuccess(conn);


        console.log('✅ Firebase sync muvaffaqiyatli');

        return true;

    } catch (error) {

        const message =
            error && error.message
                ? error.message
                : String(error);


        await markFailed(
            conn,
            item.id,
            message
        );


        await setFirebaseStatus(
            conn,
            'offline',
            message
        );


        console.log(
            '❌ Firebase sync xatosi:',
            message
        );


        return false;
    }
}


/*
|--------------------------------------------------------------------------
| Process queue
|--------------------------------------------------------------------------
*/

async function processQueue() {

    let conn = null;

    try {

        const db = initFirebase();

        conn = await createMySQLConnection();

        const items =
            await getPendingQueue(conn);


        if (items.length === 0) {

            await markFirebaseSuccess(conn);

            console.log(
                `[${new Date().toLocaleString()}]`
            );

            console.log(
                'ℹ️ sync_queue da pending ma\'lumot yo\'q.'
            );

            return;
        }


        console.log('');
        console.log(
            '================================================'
        );
        console.log(
            ' FIREBASE QUEUE WORKER'
        );
        console.log(
            '================================================'
        );

        console.log(
            `📦 Queue'da ${items.length} ta ma'lumot bor.`
        );


        let successCount = 0;
        let failedCount = 0;


        for (const item of items) {

            const success =
                await processItem(
                    db,
                    conn,
                    item
                );

            if (success) {
                successCount++;
            } else {
                failedCount++;
            }
        }


        /*
        |--------------------------------------------------------------------------
        | Final queue count
        |--------------------------------------------------------------------------
        */

        const [countRows] =
            await conn.execute(
                `
                SELECT COUNT(*) AS count
                FROM sync_queue
                WHERE status IN ('pending', 'processing', 'failed')
                `
            );

        const pendingCount =
            Number(countRows[0].count);


        console.log('');
        console.log(
            '================================================'
        );
        console.log(
            ' QUEUE NATIJASI'
        );
        console.log(
            '================================================'
        );

        console.log(
            `✅ Muvaffaqiyatli: ${successCount}`
        );

        console.log(
            `❌ Xatolik:        ${failedCount}`
        );

        console.log(
            `⏳ Qolgan queue:   ${pendingCount}`
        );

        console.log(
            '================================================'
        );


    } catch (error) {

        console.log('');
        console.log(
            '================================================'
        );

        console.log(
            '❌ FIREBASE BILAN ALOQA MAVJUD EMAS'
        );

        console.log(
            '================================================'
        );

        console.log(
            error && error.message
                ? error.message
                : error
        );


        /*
        |--------------------------------------------------------------------------
        | MySQL mavjud bo'lsa statusni offline qilamiz
        |--------------------------------------------------------------------------
        */

        try {

            if (!conn) {
                conn =
                    await createMySQLConnection();
            }

            await setFirebaseStatus(
                conn,
                'offline',
                error && error.message
                    ? error.message
                    : String(error)
            );

      } catch (mysqlConnectionError) {

    console.log(
        '❌ MySQL bilan ham aloqa o\'rnatilmadi:',
        mysqlConnectionError instanceof Error
            ? mysqlConnectionError.message
            : String(mysqlConnectionError)
    );
}

    } finally {

        if (conn) {
            await conn.end();
        }
    }
}


/*
|--------------------------------------------------------------------------
| MAIN LOOP
|--------------------------------------------------------------------------
*/

async function main() {

    console.log('');
    console.log(
        '================================================'
    );

    console.log(
        ' KU HOSTEL - FIREBASE QUEUE WORKER'
    );

    console.log(
        '================================================'
    );

    console.log(
        `Tekshirish intervali: ${POLL_INTERVAL_MS / 1000} sekund`
    );

    console.log(
        `Queue batch: ${BATCH_SIZE}`
    );

    console.log(
        `Max attempts: ${MAX_ATTEMPTS}`
    );

    console.log(
        'Worker to\'xtatish: CTRL + C'
    );

    console.log(
        '================================================'
    );


    while (true) {

        await processQueue();

        await new Promise(
            resolve =>
                setTimeout(
                    resolve,
                    POLL_INTERVAL_MS
                )
        );
    }
}


main().catch(error => {

    console.error(
        'WORKER FATAL ERROR:',
        error
    );

    process.exit(1);
});