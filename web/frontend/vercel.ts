function normalizeOrigin(value: string | undefined) {
  const raw = (value || '').trim().replace(/\/$/, '')
  if (!raw) return ''
  if (/^https?:\/\//i.test(raw)) return raw
  return `http://${raw}:8000`
}

const backendOrigin =
  normalizeOrigin(process.env.BACKEND_ORIGIN) ||
  normalizeOrigin(process.env.SERVER_HOST) ||
  'http://8.156.88.100:8000'

export default {
  rewrites: [
    {
      source: '/api/(.*)',
      destination: `${backendOrigin}/api/$1`,
    },
  ],
}
