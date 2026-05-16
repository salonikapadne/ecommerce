const Navbar = ({ activeView, setView }) => {
    return (
        <nav className="navbar">
            <button className="brand" onClick={() => setView('list')} aria-label="Show inventory">
                <span className="brand-mark">S</span>
                <span>
                    <span className="brand-title">Stockroom</span>
                    <span className="brand-subtitle">Inventory control</span>
                </span>
            </button>
            <div className="nav-links">
                <button className={activeView === 'list' ? 'active' : ''} onClick={() => setView('list')}>
                    Inventory
                </button>
                <button className={activeView === 'add' ? 'active' : ''} onClick={() => setView('add')}>
                    Add Product
                </button>
            </div>
        </nav>
    );
};

export default Navbar;
