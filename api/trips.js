const { MongoClient, ObjectId } = require('mongodb');

// MongoDB Atlas Connection URI
const uri = "mongodb+srv://abraamrefaat_db_user:NileQuest_23@cluster0.xktyimj.mongodb.net/?appName=Cluster0";
const client = new MongoClient(uri);

let dbConnection;

async function connectToDatabase() {
    if (dbConnection) return dbConnection;
    await client.connect();
    dbConnection = client.db("nile_quest");
    return dbConnection;
}

module.exports = async (req, res) => {
    // Enable CORS
    res.setHeader('Access-Control-Allow-Origin', '*');
    res.setHeader('Access-Control-Allow-Methods', 'GET, POST, DELETE, OPTIONS');
    res.setHeader('Access-Control-Allow-Headers', 'Content-Type');

    if (req.method === 'OPTIONS') {
        return res.status(204).end();
    }

    try {
        const db = await connectToDatabase();
        const collection = db.collection("trips");

        switch (req.method) {
            case 'POST':
                // Save a new trip
                const tripData = req.body;
                if (!tripData.firebaseUid || !tripData.itinerary) {
                    return res.status(400).json({ error: "Missing required fields: firebaseUid or itinerary" });
                }

                const newTrip = {
                    ...tripData,
                    createdAt: new Date(),
                    updatedAt: new Date()
                };

                const result = await collection.insertOne(newTrip);
                return res.status(201).json({
                    success: true,
                    message: "Trip saved successfully",
                    tripId: result.insertedId
                });

            case 'GET':
                // Fetch trips for a specific user
                const { uid } = req.query;
                if (!uid) {
                    return res.status(400).json({ error: "Missing user ID (uid)" });
                }

                const trips = await collection.find({ firebaseUid: uid })
                    .sort({ createdAt: -1 })
                    .toArray();

                return res.status(200).json({
                    success: true,
                    count: trips.length,
                    trips
                });

            case 'DELETE':
                // Delete a specific trip
                const { id } = req.query;
                if (!id) {
                    return res.status(400).json({ error: "Missing trip ID (id)" });
                }

                const deleteResult = await collection.deleteOne({ _id: new ObjectId(id) });
                if (deleteResult.deletedCount === 0) {
                    return res.status(404).json({ error: "Trip not found" });
                }

                return res.status(200).json({
                    success: true,
                    message: "Trip deleted successfully"
                });

            default:
                return res.status(405).json({ error: "Method Not Allowed" });
        }
    } catch (error) {
        console.error("Database Error:", error);
        return res.status(500).json({
            success: false,
            error: "Internal Server Error",
            message: error.message
        });
    }
};
