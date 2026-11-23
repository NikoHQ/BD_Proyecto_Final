// Datos ficticios. Las posiciones de las canchas son identificadores locales.
const statuses = { pending: 'Pendiente', confirmed: 'Confirmada', completed: 'Completada', cancelled: 'Cancelada', maintenance: 'Mantención' };
const statusIcons = { pending: 'hourglass-split', confirmed: 'check-circle', completed: 'check2-all', cancelled: 'x-circle', maintenance: 'tools' };
const courts = [
  ['Fútbol 7', 'Las Rastras', 'Fútbol 7', 24000],
  ['Fútbol 5', 'Las Rastras', 'Fútbol 5', 19000],
  ['Pádel 1', 'Las Rastras', 'Pádel dobles', 15000],
  ['Gimnasio multiuso', 'Las Rastras', 'Básquetbol 5x5', 22000],
  ['Cancha de vóleibol', 'La Florida', 'Vóleibol 6x6', 16000],
  ['Sala de entrenamiento', 'La Florida', 'Entrenamiento funcional', 8000]
];
const demoRows = [
  [0, 'Club Los Pinos', '08:00', '10:00', 'completed'],
  [0, 'Deportivo Austral', '11:00', '13:00', 'confirmed'],
  [0, 'Rayo Norte', '18:00', '20:00', 'pending'],
  [1, 'Escuela Municipal', '09:00', '11:00', 'completed'],
  [1, 'Unión Talca', '17:00', '19:00', 'confirmed'],
  [2, 'Amigos del Pádel', '08:30', '10:30', 'confirmed'],
  [2, 'Camila Rojas', '13:00', '15:00', 'pending'],
  [2, 'Pádel Oriente', '19:00', '21:00', 'confirmed'],
  [3, 'Los Halcones', '10:00', '12:00', 'confirmed'],
  [3, 'Mantención', '14:00', '16:00', 'maintenance'],
  [3, 'Taller deportivo', '17:00', '19:00', 'pending'],
  [4, 'Club La Florida', '11:00', '13:00', 'confirmed'],
  [5, 'Entrenamiento grupal', '09:00', '11:00', 'completed'],
  [3, 'Escuela de básquetbol', '18:30', '19:30', 'pending'],
  [2, 'Pádel Sur', '16:00', '16:45', 'cancelled']
];
const demoClients = [
  { id: 1, name: 'Camila Rojas', rut: '12345678-5', phone: '+56 9 6123 4590', email: 'camila.rojas@demo.cl', type: 'Persona' },
  { id: 2, name: 'Martín Soto', rut: '11111111-1', phone: '+56 9 7234 5601', email: 'martin.soto@demo.cl', type: 'Persona' },
  { id: 3, name: 'Daniela Pérez', rut: '22222222-2', phone: '+56 9 8345 6712', email: 'daniela.perez@demo.cl', type: 'Persona' },
  { id: 4, name: 'Ignacio Fuentes', rut: '15432109-K', phone: '+56 9 6456 7823', email: 'ignacio.fuentes@demo.cl', type: 'Persona' },
  { id: 5, name: 'Valentina Muñoz', rut: '17654321-6', phone: '+56 9 7567 8934', email: 'valentina.munoz@demo.cl', type: 'Persona' },
  { id: 6, name: 'Diego Álvarez', rut: '18765432-1', phone: '+56 9 8678 9045', email: 'diego.alvarez@demo.cl', type: 'Persona' },
  { id: 7, name: 'Fernanda Silva', rut: '20456789-3', phone: '+56 9 9789 0156', email: 'fernanda.silva@demo.cl', type: 'Persona' },
  { id: 8, name: 'Pádel Oriente', rut: '77543210-4', phone: '+56 9 8890 1267', email: 'contacto@padeloriente.demo.cl', type: 'Organización' },
  { id: 9, name: 'Club Los Pinos', rut: '76890123-9', phone: '+56 9 7901 2378', email: 'reservas@clublospinos.demo.cl', type: 'Organización' },
  { id: 10, name: 'Deportivo Austral', rut: '76901234-4', phone: '+56 9 6012 3489', email: 'contacto@deportivoaustral.demo.cl', type: 'Organización' },
  { id: 11, name: 'Escuela Municipal', rut: '60876543-2', phone: '+56 9 5123 4590', email: 'deportes@escuelamunicipal.demo.cl', type: 'Organización' },
  { id: 12, name: 'Taller deportivo', rut: '77234567-8', phone: '+56 9 4234 5601', email: 'gestion@tallerdeportivo.demo.cl', type: 'Organización' },
  { id: 13, name: 'Club La Florida', rut: '76567890-1', phone: '+56 9 3345 6712', email: 'contacto@clublaflorida.demo.cl', type: 'Organización' },
  { id: 14, name: 'Entrenamiento grupal', rut: '77456789-6', phone: '+56 9 2456 7823', email: 'info@entrenamientogrupal.demo.cl', type: 'Organización' }
];
const siteRecords = [
  { id: 1, key: 'Las Rastras', name: 'Las Rastras', district: 'Talca', address: 'Sector Las Rastras', status: 'ACTIVO' },
  { id: 2, key: 'La Florida', name: 'La Florida', district: 'Talca', address: 'Sector La Florida', status: 'ACTIVO' }
];
