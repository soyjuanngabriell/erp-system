"use client"

import { useState } from "react"
import { Button } from "@/components/ui/button"
import { Input } from "@/components/ui/input"
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card"
import { Badge } from "@/components/ui/badge"
import { Loader2, Search, User, Building, Phone, Mail, MapPin, CheckCircle } from "lucide-react"
import { useToast } from "@/hooks/use-toast"
import { 
  searchContributorsByName, 
  searchContributorsByRnc, 
  formatRnc, 
  cleanRnc, 
  isValidRnc,
  getContributorDisplayName,
  getStatusColor,
  type RncContributor 
} from "@/lib/utils/rnc-api"

interface ContributorSearchProps {
  onSelectContributor: (contributor: RncContributor) => void
  placeholder?: string
  searchBy?: 'name' | 'rnc' | 'both'
  className?: string
}

export function ContributorSearch({ 
  onSelectContributor, 
  placeholder = "Buscar por nombre o RNC...",
  searchBy = 'both',
  className = ""
}: ContributorSearchProps) {
  const { toast } = useToast()
  const [searchTerm, setSearchTerm] = useState("")
  const [isSearching, setIsSearching] = useState(false)
  const [searchResults, setSearchResults] = useState<RncContributor[]>([])
  const [showResults, setShowResults] = useState(false)

  const handleSearch = async () => {
    if (!searchTerm.trim()) {
      toast({
        title: "Error",
        description: "Por favor ingresa un nombre o RNC para buscar",
        variant: "destructive",
      })
      return
    }

    setIsSearching(true)
    setShowResults(false)

    try {
      let results: RncContributor[] = []

      if (searchBy === 'name' || searchBy === 'both') {
        const nameResults = await searchContributorsByName(searchTerm.trim())
        results = [...results, ...nameResults.data]
      }

      if (searchBy === 'rnc' || searchBy === 'both') {
        if (isValidRnc(searchTerm)) {
          const rncResults = await searchContributorsByRnc(searchTerm.trim())
          results = [...results, ...rncResults.data]
        }
      }

      // Remove duplicates based on RNC
      const uniqueResults = results.filter((contributor, index, self) => 
        index === self.findIndex(c => c.rnc === contributor.rnc)
      )

      setSearchResults(uniqueResults)
      setShowResults(true)

      if (uniqueResults.length === 0) {
        toast({
          title: "Sin resultados",
          description: "No se encontraron contribuyentes con ese criterio de búsqueda",
          variant: "destructive",
        })
      } else {
        toast({
          title: "Búsqueda exitosa",
          description: `Se encontraron ${uniqueResults.length} contribuyente(s)`,
        })
      }
    } catch (error) {
      console.error('Search error:', error)
      toast({
        title: "Error de búsqueda",
        description: error instanceof Error ? error.message : "Error al buscar contribuyentes",
        variant: "destructive",
      })
    } finally {
      setIsSearching(false)
    }
  }

  const handleSelectContributor = (contributor: RncContributor) => {
    onSelectContributor(contributor)
    setShowResults(false)
    setSearchTerm("")
    setSearchResults([])
    
    toast({
      title: "Contribuyente seleccionado",
      description: `${getContributorDisplayName(contributor)} ha sido seleccionado`,
    })
  }

  const handleKeyPress = (e: React.KeyboardEvent) => {
    if (e.key === 'Enter') {
      handleSearch()
    }
  }

  return (
    <div className={`space-y-4 ${className}`}>
      <Card>
        <CardHeader>
          <CardTitle className="flex items-center gap-2">
            <Search className="h-5 w-5" />
            Búsqueda de Contribuyentes
          </CardTitle>
        </CardHeader>
        <CardContent className="space-y-4">
          <div className="flex gap-2">
            <Input
              placeholder={placeholder}
              value={searchTerm}
              onChange={(e) => setSearchTerm(e.target.value)}
              onKeyPress={handleKeyPress}
              disabled={isSearching}
            />
            <Button 
              onClick={handleSearch} 
              disabled={isSearching || !searchTerm.trim()}
              className="min-w-[100px]"
            >
              {isSearching ? (
                <>
                  <Loader2 className="mr-2 h-4 w-4 animate-spin" />
                  Buscando...
                </>
              ) : (
                <>
                  <Search className="mr-2 h-4 w-4" />
                  Buscar
                </>
              )}
            </Button>
          </div>

          {showResults && searchResults.length > 0 && (
            <div className="space-y-2">
              <h4 className="text-sm font-medium text-muted-foreground">
                Resultados ({searchResults.length})
              </h4>
              <div className="max-h-96 overflow-y-auto space-y-2">
                {searchResults.map((contributor) => (
                  <Card 
                    key={contributor.rnc} 
                    className="cursor-pointer hover:bg-muted/50 transition-colors"
                    onClick={() => handleSelectContributor(contributor)}
                  >
                    <CardContent className="p-4">
                      <div className="flex items-start justify-between">
                        <div className="space-y-2 flex-1">
                          <div className="flex items-center gap-2">
                            <Building className="h-4 w-4 text-muted-foreground" />
                            <h5 className="font-medium">{getContributorDisplayName(contributor)}</h5>
                            <Badge 
                              variant="outline" 
                              className={`text-xs ${getStatusColor(contributor.status)}`}
                            >
                              {contributor.status}
                            </Badge>
                          </div>
                          
                          <div className="space-y-1 text-sm text-muted-foreground">
                            <div className="flex items-center gap-2">
                              <User className="h-3 w-3" />
                              <span>RNC: {formatRnc(contributor.rnc)}</span>
                            </div>
                            
                            {contributor.economic_activity && (
                              <div className="flex items-center gap-2">
                                <MapPin className="h-3 w-3" />
                                <span>{contributor.economic_activity}</span>
                              </div>
                            )}
                            
                            {contributor.location && (
                              <div className="flex items-center gap-2">
                                <MapPin className="h-3 w-3" />
                                <span>{contributor.location}</span>
                              </div>
                            )}
                            
                            {contributor.phone && (
                              <div className="flex items-center gap-2">
                                <Phone className="h-3 w-3" />
                                <span>{contributor.phone}</span>
                              </div>
                            )}
                            
                            {contributor.email && (
                              <div className="flex items-center gap-2">
                                <Mail className="h-3 w-3" />
                                <span>{contributor.email}</span>
                              </div>
                            )}
                          </div>
                        </div>
                        
                        <div className="flex items-center gap-2 ml-4">
                          <Badge variant="secondary" className="text-xs">
                            {contributor.payment_type}
                          </Badge>
                          <CheckCircle className="h-4 w-4 text-green-600" />
                        </div>
                      </div>
                    </CardContent>
                  </Card>
                ))}
              </div>
            </div>
          )}
        </CardContent>
      </Card>
    </div>
  )
}
