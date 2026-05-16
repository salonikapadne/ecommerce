const express = require('express');
const mongoose = require('mongoose');
const cors = require('cors');
require('dotenv').config();

const app = express();
const PORT = process.env.PORT || 5000;

// Middleware
app.use(cors());
app.use(express.json());

// Routes
const productRoutes = require('./routes/productRoutes');
app.use('/api/products', productRoutes);

// Root Route
app.get('/', (req, res) => {
    res.send('E-commerce Management API is running...');
});

// MongoDB Connection (Local Instance)
mongoose.connect(process.env.MONGO_URI || 'mongodb://127.0.0.1:27017/ecommerce-db')
    .then(() => {
        console.log('Connected to Local MongoDB');
        app.listen(PORT, '0.0.0.0', () => {
            console.log(`Server is running on port ${PORT}`);
        });
    })
    .catch(err => {
        console.error('Database connection error:', err);
    });
 