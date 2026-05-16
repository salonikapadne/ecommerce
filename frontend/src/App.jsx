import { useState } from 'react';
import Navbar from './components/Navbar';
import ProductList from './components/ProductList';
import ProductForm from './components/ProductForm';
import './App.css';

function App() {
    const [view, setView] = useState('list');
    const [currentProduct, setCurrentProduct] = useState(null);

    const handleEdit = (product) => {
        setCurrentProduct(product);
        setView('add');
    };

    const handleSave = () => {
        setCurrentProduct(null);
        setView('list');
    };

    return (
        <div className="App">
            <Navbar
                activeView={view}
                setView={(v) => { setView(v); setCurrentProduct(null); }}
            />
            <main className="container">
                {view === 'list' ? (
                    <ProductList onEdit={handleEdit} />
                ) : (
                    <ProductForm currentProduct={currentProduct} onSave={handleSave} />
                )}
            </main>
        </div>
    );
}

export default App;
