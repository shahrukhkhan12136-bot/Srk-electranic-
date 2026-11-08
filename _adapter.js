// Adapter for the existing server-side handlers on Vercel.
module.exports = async function adapt(handler, req, res) {
  const event = {
    httpMethod: req.method,
    headers: req.headers || {},
    body: req.body === undefined ? '' : (typeof req.body === 'string' ? req.body : JSON.stringify(req.body)),
    queryStringParameters: req.query || {}
  };
  try {
    const result = await handler(event);
    const headers = result.headers || {};
    for (const [key, value] of Object.entries(headers)) res.setHeader(key, value);
    res.status(result.statusCode || 200);
    if (result.body === undefined || result.body === null || result.body === '') return res.end();
    return res.send(result.body);
  } catch (error) {
    console.error('API adapter error:', error);
    return res.status(500).json({ error: 'सर्वर में समस्या हुई।' });
  }
};
