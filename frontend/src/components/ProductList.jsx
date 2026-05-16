import { useCallback, useEffect, useState } from 'react';
import axios from 'axios';

const ProductList = ({ onEdit }) => {
    const [products, setProducts] = useState([]);
    const [loading, setLoading] = useState(true);
    const [error, setError] = useState('');

    const API_URL = import.meta.env.VITE_API_URL || 'http://127.0.0.1:5000/api/products';

    const fetchProducts = useCallback(async () => {
        try {
            setError('');
            const res = await axios.get(API_URL);
            setProducts(res.data);
            setLoading(false);
        } catch (err) {
            console.error('Error fetching products:', err);
            setError('Could not load inventory. Check that the backend server is running.');
            setLoading(false);
        }
    }, [API_URL]);

    useEffect(() => {
        // eslint-disable-next-line react-hooks/set-state-in-effect
        fetchProducts();
    }, [fetchProducts]);

    const deleteProduct = async (id) => {
        if (window.confirm('Delete this product from inventory?')) {
            try {
                await axios.delete(`${API_URL}/${id}`);
                fetchProducts();
            } catch (err) {
                console.error('Error deleting product:', err);
            }
        }
    };

    if (loading) {
        return (
            <section className="data-view">
                <div className="page-heading">
                    <p className="eyebrow">Inventory</p>
                    <h2>Product Catalog</h2>
                </div>
                <div className="state-card">Loading inventory...</div>
            </section>
        );
    }

    return (
        <section className="data-view">
            <div className="page-heading">
                <p className="eyebrow">Inventory</p>
                <h2>Product Catalog</h2>
                <p className="section-copy">Track catalog items, pricing, categories, and stock from one clean inventory board.</p>
            </div>
            {error ? (
                <div className="state-card error-state">{error}</div>
            ) : products.length === 0 ? (
                <div className="state-card">
                    <strong>No products yet</strong>
                    <span>Add the first product to build the catalog.</span>
                </div>
            ) : (
                <div className="table-shell">
                    <table>
                        <thead>
                            <tr>
                                <th>Product</th>
                                <th>Category</th>
                                <th>Price</th>
                                <th>Stock</th>
                                <th>Actions</th>
                            </tr>
                        </thead>
                        <tbody>
                            {products.map((product) => (
                                <tr key={product._id}>
                                    <td className="strong-cell">{product.name}</td>
                                    <td><span className="pill">{product.category}</span></td>
                                    <td>${product.price}</td>
                                    <td>{product.stock}</td>
                                    <td className="actions-cell">
                                        <button onClick={() => onEdit(product)}>Edit</button>
                                        <button className="btn-delete" onClick={() => deleteProduct(product._id)}>Delete</button>
                                    </td>
                                </tr>
                            ))}
                        </tbody>
                    </table>
                </div>
            )}
        </section>
    );
};

export default ProductList;
