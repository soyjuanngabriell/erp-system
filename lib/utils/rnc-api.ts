// RNC API integration utilities
export interface RncContributor {
  rnc: string
  name: string
  commercial_name?: string
  status: string
  payment_type: string
  economic_activity?: string
  location?: string
  phone?: string
  email?: string
}

export interface RncApiResponse {
  data: RncContributor[]
  total: number
  page: number
  limit: number
}

/**
 * Search for contributors by name using the RNC API
 * @param name - The name to search for
 * @param page - Page number (default: 1)
 * @param limit - Results per page (default: 1)
 * @returns Promise with RNC API response
 */
export async function searchContributorsByName(
  name: string, 
  page: number = 1, 
  limit: number = 1
): Promise<RncApiResponse> {
  try {
    const encodedName = encodeURIComponent(name.trim())
    const url = `https://rnc-contributors.vercel.app/api/contributors/name/${encodedName}?page=${page}&limit=${limit}`
    
    const response = await fetch(url, {
      method: 'GET',
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      },
    })

    if (!response.ok) {
      throw new Error(`HTTP error! status: ${response.status}`)
    }

    const data: RncApiResponse = await response.json()
    return data
  } catch (error) {
    console.error('Error searching contributors by name:', error)
    throw new Error('Error al buscar contribuyentes. Por favor, inténtalo de nuevo.')
  }
}

/**
 * Search for contributors by RNC using the RNC API
 * @param rnc - The RNC to search for
 * @param page - Page number (default: 1)
 * @param limit - Results per page (default: 1)
 * @returns Promise with RNC API response
 */
export async function searchContributorsByRnc(
  rnc: string, 
  page: number = 1, 
  limit: number = 1
): Promise<RncApiResponse> {
  try {
    const cleanRnc = rnc.replace(/[^0-9]/g, '') // Remove non-numeric characters
    const url = `https://rnc-contributors.vercel.app/api/contributors/rnc/${cleanRnc}?page=${page}&limit=${limit}`
    
    const response = await fetch(url, {
      method: 'GET',
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      },
    })

    if (!response.ok) {
      throw new Error(`HTTP error! status: ${response.status}`)
    }

    const data: RncApiResponse = await response.json()
    return data
  } catch (error) {
    console.error('Error searching contributors by RNC:', error)
    throw new Error('Error al buscar contribuyentes por RNC. Por favor, inténtalo de nuevo.')
  }
}

/**
 * Format RNC for display (adds dashes)
 * @param rnc - Raw RNC string
 * @returns Formatted RNC string
 */
export function formatRnc(rnc: string): string {
  const cleanRnc = rnc.replace(/[^0-9]/g, '')
  if (cleanRnc.length === 9) {
    return `${cleanRnc.slice(0, 3)}-${cleanRnc.slice(3, 8)}-${cleanRnc.slice(8)}`
  }
  return cleanRnc
}

/**
 * Clean RNC for API calls (removes dashes and spaces)
 * @param rnc - RNC string with formatting
 * @returns Clean RNC string
 */
export function cleanRnc(rnc: string): string {
  return rnc.replace(/[^0-9]/g, '')
}

/**
 * Validate RNC format
 * @param rnc - RNC to validate
 * @returns true if valid format
 */
export function isValidRnc(rnc: string): boolean {
  const cleanRnc = rnc.replace(/[^0-9]/g, '')
  return cleanRnc.length === 9
}

/**
 * Get contributor display name (prefers commercial name over name)
 * @param contributor - Contributor data
 * @returns Display name
 */
export function getContributorDisplayName(contributor: RncContributor): string {
  return contributor.commercial_name || contributor.name
}

/**
 * Get contributor status color for UI
 * @param status - Contributor status
 * @returns CSS color class
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
