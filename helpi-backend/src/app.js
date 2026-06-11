const express = require('express');
const app = express();

app.use(express.json());

// Rota de teste básica
app.get('/api/status', (req, res) => {
    res.json({ message: "Motor do Helpi funcionando perfeitamente!" });
});

module.exports = app;