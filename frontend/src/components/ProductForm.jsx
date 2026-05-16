import { useState } from 'react';
import axios from 'axios';

const emptyProduct = { name: '', price: '', category: '', description: '', stock: '' };

const ProductForm = ({ currentProduct, onSave }) => {
    const [product, setProduct] = useState(currentProduct || emptyProduct);
    const API_URL = import.meta.env.VITE_API_URL || 'http://127.0.0.1:5000/api/products';

    const handleChange = (e) => {
        setProduct({ ...product, [e.target.name]: e.target.value });
    };

    const handleSubmit = async (e) => {
        e.preventDefault();
        try {
            if (currentProduct) {
                await axios.put(`${API_URL}/${currentProduct._id}`, product);
            } else {
                await axios.post(API_URL, product);
            }
            onSave();
        } catch (err) {
            console.error('Error saving product:', err);
            alert('Error: ' + (err.response?.data?.message || err.message));
        }
    };

    return (
        <section className="form-view">
            <div className="page-heading">
                <p className="eyebrow">{currentProduct ? 'Inventory update' : 'New item'}</p>
                <h2>{currentProduct ? 'Edit Product' : 'Add Product'}</h2>
                <p className="section-copy">Keep product details consistent before they reach the catalog.</p>
            </div>
            <form onSubmit={handleSubmit}>
                <div className="form-group">
                    <label htmlFor="name">Product Name</label>
                    <input
                        id="name"
                        type="text"
                        name="name"
                        value={product.name}
                        onChange={handleChange}
                        placeholder="Wireless keyboard"
                        required
                    />
                </div>
                <div className="form-group">
                    <label htmlFor="category">Category</label>
                    <input
                        id="category"
                        type="text"
                        name="category"
                        value={product.category}
                        onChange={handleChange}
                        placeholder="Accessories"
                        required
                    />
                </div>
                <div className="form-row">
                    <div className="form-group">
                        <label htmlFor="price">Price</label>
                        <input
                            id="price"
                            type="number"
                            name="price"
                            value={product.price}
                            onChange={handleChange}
                            placeholder="49"
                            required
                        />
                    </div>
                    <div className="form-group">
                        <label htmlFor="stock">Stock Quantity</label>
                        <input
                            id="stock"
                            type="number"
                            name="stock"
                            value={product.stock}
                            onChange={handleChange}
                            placeholder="120"
                            required
                        />
                    </div>
                </div>
                <div className="form-group">
                    <label htmlFor="description">Description</label>
                    <textarea
                        id="description"
                        name="description"
                        value={product.description}
                        onChange={handleChange}
                        placeholder="Short catalog description..."
                        required
                    ></textarea>
                </div>
                <div className="form-actions">
                    <button type="submit" className="btn-primary">{currentProduct ? 'Update Inventory' : 'Add to Inventory'}</button>
                    <button type="button" className="btn-cancel" onClick={onSave}>Cancel</button>
                </div>
            </form>
        </section>
    );
};

export default ProductForm;
