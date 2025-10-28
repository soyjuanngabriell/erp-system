// rncApi.ts

export interface RncContributor {
  rnc: string
  social_reason: string
  commercial_name?: string
  status: string
  payment_type: string
  economic_activity?: string
  location?: string
  phone?: string
  email?: string
}

export interface RncApiListResponse {
  total: number
  totalPages: number
  currentPage: number
  prevPage: number | null
  nextPage: number | null
  data: RncContributor[]
}

/**
 * Determina si una cadena parece ser un RNC válido (9 dígitos)
 */
export function isValidRnc(rnc: string): boolean {
  const clean = rnc.replace(/[^0-9]/g, '')
  return clean.length === 9
}

/**
 * Limpia un RNC de guiones o espacios
 */
export function cleanRnc(rnc: string): string {
  return rnc.replace(/[^0-9]/g, '')
}

/**
 * Formatea un RNC (XXX-XXXXX-X)
 */
export function formatRnc(rnc: string): string {
  const clean = cleanRnc(rnc)
  return clean.length === 9
    ? `${clean.slice(0, 3)}-${clean.slice(3, 8)}-${clean.slice(8)}`
    : clean
}

/**
 * Obtiene el nombre más legible del contribuyente
 */
export function getContributorDisplayName(contributor: RncContributor): string {
  return contributor.commercial_name || contributor.social_reason
}

/**
 * Devuelve color de estado para la UI
 */
export function getStatusColor(status: string): string {
  switch (status.toLowerCase()) {
    case 'activo':
      return 'text-green-600'
    case 'inactivo':
      return 'text-red-600'
    case 'suspendido':
      return 'text-yellow-600'
    default:
      return 'text-gray-600'
  }
}

/**
 * Busca contribuyentes por nombre o razón social.
 * Devuelve hasta 5 resultados de la página 1.
 */
async function searchContributorsByName(
  name: string,
  page: number = 1,
  limit: number = 5
): Promise<RncContributor[] | null> {
  if (!name.trim()) return null

  try {
    const encodedName = encodeURIComponent(name.trim())
    const url = `https://rnc-contributors.vercel.app/api/contributors/name/${encodedName}?page=${page}&limit=${limit}`

    const response = await fetch(url, { headers: { Accept: 'application/json' } })
    if (!response.ok) {
      console.warn('RNC API Name request failed:', response.status)
      return null
    }

    const data = await response.json()
    if (!data?.data || !Array.isArray(data.data)) return null

    return data.data
  } catch (error) {
    console.error('Error buscando por nombre o razón social:', error)
    return null
  }
}

/**
 * Busca un contribuyente por RNC.
 */
async function searchContributorsByRnc(
  rnc: string
): Promise<RncContributor | null> {
  if (!rnc.trim()) return null

  try {
    const clean = cleanRnc(rnc)
    const url = `https://rnc-contributors.vercel.app/api/contributors/rnc/${clean}`

    const response = await fetch(url, { headers: { Accept: 'application/json' } })
    if (!response.ok) {
      console.warn('RNC API RNC request failed:', response.status)
      return null
    }

    const data = await response.json()
    return data?.rnc ? data : null
  } catch (error) {
    console.error('Error buscando por RNC:', error)
    return null
  }
}

/**
 * 🔍 Función principal que detecta si la búsqueda es por RNC o por nombre
 * Si es un número válido → busca por RNC
 * Si es texto → busca por nombre (máx. 5 resultados)
 */
export async function searchContributor(query: string): Promise<RncContributor[] | null> {
  if (!query.trim()) return null

  // Detecta si es un RNC
  if (isValidRnc(query)) {
    const result = await searchContributorsByRnc(query)
    return result ? [result] : null
  }

  // Si no es RNC, busca por nombre
  const results = await searchContributorsByName(query, 1, 5)
  return results
}
