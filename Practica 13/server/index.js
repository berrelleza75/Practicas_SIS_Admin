require('dotenv').config();
const express = require('express');
const cors = require('cors');

const machinesRouter = require('./routes/machines');
const usersRouter = require('./routes/users');
const servicesRouter = require('./routes/services');

const app = express();
const PORT = process.env.PORT || 3001;

app.use(cors({ origin: 'http://localhost:5173' }));
app.use(express.json());

app.use('/api/machines', machinesRouter);
app.use('/api/users', usersRouter);
app.use('/api/services', servicesRouter);

app.get('/api/health', (req, res) => res.json({ ok: true }));

app.listen(PORT, () => {
  console.log(`SIS-ADMIN API corriendo en http://localhost:${PORT}`);
});
