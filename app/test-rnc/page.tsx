"use client"

import { useState } from "react"
import { Button } from "@/components/ui/button"
import { Input } from "@/components/ui/input"
import { Label } from "@/components/ui/label"
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card"
import { Badge } from "@/components/ui/badge"
import { Loader2, Search, TestTube } from "lucide-react"
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

export default function RncTestPage() {
  const { toast } = useToast()
  const [searchTerm, setSearchTerm] = useState("")
  const [isSearching, setIsSearching] = useState(false)
  const [searchResults, setSearchResults] = useState<RncContributor[]>([])
  const [searchType, setSearchType] = useState<'name' | 'rnc'>('name')

  const handleSearch = async () => {
    if (!searchTerm.trim()) {
      toast({
        title: "Error",
        description: "Por favor ingresa un término de búsqueda",
        variant: "destructive",
      })
      return
    }

    setIsSearching(true)
    setSearchResults([])

    try {
      let results: RncContributor[] = []

      if (searchType === 'name') {
        const nameResults = await searchContributorsByName(searchTerm.trim())
        results = nameResults.data
      } else {
        if (isValidRnc(searchTerm)) {
          const rncResults = await searchContributorsByRnc(searchTerm.trim())
          results = rncResults.data
        } else {
          throw new Error("Formato de RNC inválido. Debe tener 9 dígitos.")
        }
      }

      setSearchResults(results)

      if (results.length === 0) {
        toast({
          title: "Sin resultados",
          description: "No se encontraron contribuyentes con ese criterio de búsqueda",
          variant: "destructive",
        })
      } else {
        toast({
          title: "Búsqueda exitosa",
          description: `Se encontraron ${results.length} contribuyente(s)`,
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

  const handleKeyPress = (e: React.KeyboardEvent) => {
    if (e.key === 'Enter') {
      handleSearch()
    }
  }

  return (
    <div className="container mx-auto py-8 space-y-6">
      <div className="text-center">
        <h1 className="text-3xl font-bold flex items-center justify-center gap-2">
          <TestTube className="h-8 w-8" />
          Prueba de API RNC
        </h1>
        <p className="text-muted-foreground mt-2">
          Prueba la integración con la API de contribuyentes de RNC
        </p>
      </div>

      <Card className="max-w-2xl mx-auto">
        <CardHeader>
          <CardTitle>Búsqueda de Contribuyentes</CardTitle>
        </CardHeader>
        <CardContent className="space-y-4">
          <div className="space-y-2">
            <Label>Tipo de Búsqueda</Label>
            <div className="flex gap-2">
              <Button
                variant={searchType === 'name' ? 'default' : 'outline'}
                onClick={() => setSearchType('name')}
                size="sm"
              >
                Por Nombre
              </Button>
              <Button
                variant={searchType === 'rnc' ? 'default' : 'outline'}
                onClick={() => setSearchType('rnc')}
                size="sm"
              >
                Por RNC
              </Button>
            </div>
          </div>

          <div className="space-y-2">
            <Label htmlFor="searchTerm">
              {searchType === 'name' ? 'Nombre del Contribuyente' : 'RNC'}
            </Label>
            <div className="flex gap-2">
              <Input
                id="searchTerm"
                placeholder={
                  searchType === 'name' 
                    ? "Ej: Empresa ABC" 
                    : "Ej: 000-0000000-0"
                }
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
          </div>

          {searchResults.length > 0 && (
            <div className="space-y-2">
              <h4 className="text-sm font-medium text-muted-foreground">
                Resultados ({searchResults.length})
              </h4>
              <div className="max-h-96 overflow-y-auto space-y-2">
                {searchResults.map((contributor) => (
                  <Card key={contributor.rnc} className="border">
                    <CardContent className="p-4">
                      <div className="flex items-start justify-between">
                        <div className="space-y-2 flex-1">
                          <div className="flex items-center gap-2">
                            <h5 className="font-medium">{getContributorDisplayName(contributor)}</h5>
                            <Badge 
                              variant="outline" 
                              className={`text-xs ${getStatusColor(contributor.status)}`}
                            >
                              {contributor.status}
                            </Badge>
                          </div>
                          
                          <div className="space-y-1 text-sm text-muted-foreground">
                            <div>
                              <span className="font-medium">RNC:</span> {formatRnc(contributor.rnc)}
                            </div>
                            
                            {contributor.economic_activity && (
                              <div>
                                <span className="font-medium">Actividad:</span> {contributor.economic_activity}
                              </div>
                            )}
                            
                            {contributor.location && (
                              <div>
                                <span className="font-medium">Ubicación:</span> {contributor.location}
                              </div>
                            )}
                            
                            {contributor.phone && (
                              <div>
                                <span className="font-medium">Teléfono:</span> {contributor.phone}
                              </div>
                            )}
                            
                            {contributor.email && (
                              <div>
                                <span className="font-medium">Email:</span> {contributor.email}
                              </div>
                            )}
                          </div>
                        </div>
                        
                        <div className="flex items-center gap-2 ml-4">
                          <Badge variant="secondary" className="text-xs">
                            {contributor.payment_type}
                          </Badge>
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

      <Card className="max-w-2xl mx-auto">
        <CardHeader>
          <CardTitle>Información de la API</CardTitle>
        </CardHeader>
        <CardContent className="space-y-2 text-sm text-muted-foreground">
          <p><strong>Endpoint:</strong> https://rnc-contributors.vercel.app/api/contributors/</p>
          <p><strong>Búsqueda por nombre:</strong> /name/{`{nombre}`}?page=1&limit=1</p>
          <p><strong>Búsqueda por RNC:</strong> /rnc/{`{rnc}`}?page=1&limit=1</p>
          <p><strong>Formato RNC:</strong> 9 dígitos (ej: 000000000)</p>
        </CardContent>
      </Card>
    </div>
  )
}
