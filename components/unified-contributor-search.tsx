"use client"

import { useState } from "react"
import { Button } from "@/components/ui/button"
import { Input } from "@/components/ui/input"
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card"
import { Badge } from "@/components/ui/badge"
import { Loader2, Search, User, Building, Phone, Mail, MapPin, CheckCircle } from "lucide-react"
import { useToast } from "@/hooks/use-toast"
import { 
  searchContributor,
  formatRnc,
  getContributorDisplayName,
  getStatusColor,
  type RncContributor 
} from "@/lib/utils/rnc-api"

interface UnifiedContributorSearchProps {
  onSelectContributor: (contributor: RncContributor) => void
  placeholder?: string
  className?: string
}

export function UnifiedContributorSearch({ 
  onSelectContributor, 
  placeholder = "Buscar por RNC, nombre o razón social...",
  className = ""
}: UnifiedContributorSearchProps) {
  const { toast } = useToast()
  const [searchTerm, setSearchTerm] = useState("")
  const [isSearching, setIsSearching] = useState(false)
  const [searchResults, setSearchResults] = useState<RncContributor[]>([])
  const [showResults, setShowResults] = useState(false)

  const handleSearch = async () => {
    if (!searchTerm.trim()) {
      toast({
        title: "Error",
        description: "Por favor ingresa un RNC, nombre o razón social para buscar",
        variant: "destructive",
      })
      return
    }

    setIsSearching(true)
    setShowResults(false)

    try {
      const results = await searchContributor(searchTerm.trim())
      
      if (results && results.length > 0) {
        setSearchResults(results)
        setShowResults(true)
        toast({
          title: "Búsqueda exitosa",
          description: `Se encontraron ${results.length} contribuyente(s)`,
        })
      } else {
        setSearchResults([])
        setShowResults(true)
        toast({
          title: "Sin resultados",
          description: "No se encontraron contribuyentes con ese criterio de búsqueda",
          variant: "destructive",
        })
      }
    } catch (error) {
      console.error('Search error:', error)
      toast({
        title: "Error de búsqueda",
        description: "Error al buscar contribuyentes. Por favor, inténtalo de nuevo.",
        variant: "destructive",
      })
    } finally {
      setIsSearching(false)
    }
  }

  const handleKeyPress = (e: React.KeyboardEvent) => {
    if (e.key === 'Enter') {
      handleSearch()
    }
  }

  const handleSelectContributor = (contributor: RncContributor) => {
    onSelectContributor(contributor)
    setShowResults(false)
    setSearchTerm("")
    toast({
      title: "Contribuyente seleccionado",
      description: `${getContributorDisplayName(contributor)} - RNC: ${formatRnc(contributor.rnc)}`,
    })
  }

  return (
    <div className={`space-y-4 ${className}`}>
      <Card>
        <CardHeader>
          <CardTitle className="flex items-center gap-2">
            <Search className="h-5 w-5" />
            Búsqueda Unificada de Contribuyentes
          </CardTitle>
        </CardHeader>
        <CardContent className="space-y-4">
          <div className="flex gap-2">
            <Input
              value={searchTerm}
              onChange={(e) => setSearchTerm(e.target.value)}
              onKeyPress={handleKeyPress}
              placeholder={placeholder}
              className="flex-1"
            />
            <Button 
              onClick={handleSearch} 
              disabled={isSearching || !searchTerm.trim()}
              className="px-6"
            >
              {isSearching ? (
                <Loader2 className="h-4 w-4 animate-spin" />
              ) : (
                <Search className="h-4 w-4" />
              )}
            </Button>
          </div>

          {showResults && (
            <div className="space-y-3">
              <h3 className="text-sm font-medium text-gray-700">
                Resultados ({searchResults.length})
              </h3>
              
              {searchResults.length > 0 ? (
                <div className="space-y-2">
                  {searchResults.map((contributor) => (
                    <Card 
                      key={contributor.rnc} 
                      className="cursor-pointer hover:bg-gray-50 transition-colors"
                      onClick={() => handleSelectContributor(contributor)}
                    >
                      <CardContent className="p-4">
                        <div className="flex items-start justify-between">
                          <div className="space-y-2">
                            <div className="flex items-center gap-2">
                              <Building className="h-4 w-4 text-gray-500" />
                              <span className="font-medium">
                                {getContributorDisplayName(contributor)}
                              </span>
                            </div>
                            
                            <div className="flex items-center gap-2 text-sm text-gray-600">
                              <User className="h-3 w-3" />
                              <span>RNC: {formatRnc(contributor.rnc)}</span>
                            </div>

                            {contributor.commercial_name && (
                              <div className="flex items-center gap-2 text-sm text-gray-600">
                                <Building className="h-3 w-3" />
                                <span>Comercial: {contributor.commercial_name}</span>
                              </div>
                            )}

                            {contributor.economic_activity && (
                              <div className="flex items-center gap-2 text-sm text-gray-600">
                                <MapPin className="h-3 w-3" />
                                <span>{contributor.economic_activity}</span>
                              </div>
                            )}

                            {contributor.phone && (
                              <div className="flex items-center gap-2 text-sm text-gray-600">
                                <Phone className="h-3 w-3" />
                                <span>{contributor.phone}</span>
                              </div>
                            )}

                            {contributor.email && (
                              <div className="flex items-center gap-2 text-sm text-gray-600">
                                <Mail className="h-3 w-3" />
                                <span>{contributor.email}</span>
                              </div>
                            )}
                          </div>

                          <div className="flex flex-col items-end gap-2">
                            <Badge 
                              variant="outline" 
                              className={`${getStatusColor(contributor.status)} border-current`}
                            >
                              {contributor.status}
                            </Badge>
                            <CheckCircle className="h-4 w-4 text-green-500" />
                          </div>
                        </div>
                      </CardContent>
                    </Card>
                  ))}
                </div>
              ) : (
                <div className="text-center py-8 text-gray-500">
                  <Search className="h-12 w-12 mx-auto mb-4 opacity-50" />
                  <p>No se encontraron contribuyentes</p>
                  <p className="text-sm">Intenta con un término de búsqueda diferente</p>
                </div>
              )}
            </div>
          )}
        </CardContent>
      </Card>
    </div>
  )
}
