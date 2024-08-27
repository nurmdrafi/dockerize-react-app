import logo from './logo.svg';
import './App.css';

function App() {
  const BASE_URL = window?._env_?.REACT_APP_API_BASE_URL
  return (
    <div className="App">
      <header className="App-header">
        <img src={logo} className="App-logo" alt="logo" />
        <a
          className="App-link"
          href="https://reactjs.org"
          target="_blank"
          rel="noopener noreferrer"
        >
          Base Url = {BASE_URL}
        </a>
      </header>
    </div>
  );
}

export default App;
