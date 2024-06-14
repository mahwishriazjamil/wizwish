const express = require('express');
const mongoose = require('mongoose');

const app = express();
const port = 8080;

// MongoDB connection string
const mongoUri = process.env.MONGODB_URI || 'mongodb://localhost:27017';

// Connect to MongoDB
mongoose.connect(mongoUri, { useNewUrlParser: true, useUnifiedTopology: true })
  .then(() => console.log('MongoDB connected'))
  .catch(err => console.error('MongoDB connection error:', err));

// Basic route
app.get('/', (req, res) => {
  res.send('Hello, Wiz!');
});

// Start the server
app.listen(port, () => {
  console.log(`App listening at http://localhost:${port}`);
});
