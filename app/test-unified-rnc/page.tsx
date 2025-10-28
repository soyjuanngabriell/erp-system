"use client"

import { useState } from "react"
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card"
import { Badge } from "@/components/ui/badge"
import { Button } from "@/components/ui/button"
import { TestTube, CheckCircle, XCircle, Info } from "lucide-react"
import { useToast } from "@/hooks/use-toast"
import { UnifiedContributorSearch } from "@/components/unified-contributor-search"
import { 
  searchContributor,
  formatRnc,
  getContributorDisplayName,
  isValidRnc,
  cleanRnc,
  type RncContributor 
} from "@/lib/utils/rnc-api"

export default function RncUnifiedTestPage() {
  const { toast } = useToast()
  const [selectedContributor, setSelectedContributor] = useState<RncContributor | null>(null)
  const [testResults, setTestResults] = useState<{
    rnc: boolean
    name: boolean
    spaces: boolean
    invalid: boolean
  }>({
    rnc: false,
    name: false,
    spaces: false,
    invalid: false
  })

  const handleSelectContributor = (contributor: RncContributor) => {
    setSelectedContributor(contributor)
  }

  const runTests = async () => {
    const results = { rnc: false, name: false, spaces: false, invalid: false }
    
    try {
      // Test 1: RNC válido
      const rncResult = await searchContributor("131939252")
      results.rnc = rncResult && rncResult.length > 0
      
      // Test 2: Búsqueda por nombre
      const nameResult = await searchContributor("GRUPO LIS")
      results.name = nameResult && nameResult.length > 0
      
      // Test 3: Búsqueda con espacios
      const spacesResult = await searchContributor("grupo lis digital")
      results.spaces = spacesResult && spacesResult.length > 0
      
      // Test 4: RNC inválido
      const invalidResult = await searchContributor("123")
      results.invalid = !invalidResult || invalidResult.length === 0
      
      setTestResults(results)
      
      toast({
        title: "Tests completados",
        description: `RNC: ${results.rnc ? '✅' : '❌'} | Nombre: ${results.name ? '✅' : '❌'} | Espacios: ${results.spaces ? '✅' : '❌'} | Inválido: ${results.invalid ? '✅' : '❌'}`,
      })
    } catch (error) {
      console.error('Test error:', error)
      toast({
        title: "Error en tests",
        description: "Error al ejecutar las pruebas",
        variant: "destructive",
      })
    }
  }

  return (
    <div className="container mx-auto py-8 space-y-8">
      <div className="text-center space-y-4">
        <div className="flex items-center justify-center gap-2">
          <TestTube className="h-8 w-8 text-blue-600" />
          <h1 className="text-3xl font-bold">Sistema Unificado de Búsqueda RNC</h1>
        </div>
        <p className="text-gray-600 max-w-2xl mx-auto">
          Sistema mejorado que detecta automáticamente si buscas por RNC o por nombre/razón social.
          Utiliza la API pública de RNC Contributors para obtener información actualizada.
        </p>
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-2 gap-8">
        {/* Búsqueda Unificada */}
        <div>
          <UnifiedContributorSearch 
            onSelectContributor={handleSelectContributor}
            placeholder="Prueba: 131939252 o 'GRUPO LIS' o 'grupo lis digital'"
          />
        </div>

        {/* Resultado Seleccionado */}
        <div>
          <Card>
            <CardHeader>
              <CardTitle className="flex items-center gap-2">
                <CheckCircle className="h-5 w-5 text-green-600" />
                Contribuyente Seleccionado
              </CardTitle>
            </CardHeader>
            <CardContent>
              {selectedContributor ? (
                <div className="space-y-4">
                  <div className="grid grid-cols-2 gap-4 text-sm">
                    <div>
                      <span className="font-medium text-gray-600">RNC:</span>
                      <p className="font-mono">{formatRnc(selectedContributor.rnc)}</p>
                    </div>
                    <div>
                      <span className="font-medium text-gray-600">Estado:</span>
                      <Badge variant="outline" className="ml-2">
                        {selectedContributor.status}
                      </Badge>
                    </div>
                    <div className="col-span-2">
                      <span className="font-medium text-gray-600">Razón Social:</span>
                      <p>{selectedContributor.social_reason}</p>
                    </div>
                    {selectedContributor.commercial_name && (
                      <div className="col-span-2">
                        <span className="font-medium text-gray-600">Nombre Comercial:</span>
                        <p>{selectedContributor.commercial_name}</p>
                      </div>
                    )}
                    {selectedContributor.economic_activity && (
                      <div className="col-span-2">
                        <span className="font-medium text-gray-600">Actividad Económica:</span>
                        <p>{selectedContributor.economic_activity}</p>
                      </div>
                    )}
                    {selectedContributor.phone && (
                      <div>
                        <span className="font-medium text-gray-600">Teléfono:</span>
                        <p>{selectedContributor.phone}</p>
                      </div>
                    )}
                    {selectedContributor.email && (
                      <div>
                        <span className="font-medium text-gray-600">Email:</span>
                        <p>{selectedContributor.email}</p>
                      </div>
                    )}
                  </div>
                </div>
              ) : (
                <div className="text-center py-8 text-gray-500">
                  <XCircle className="h-12 w-12 mx-auto mb-4 opacity-50" />
                  <p>No hay contribuyente seleccionado</p>
                  <p className="text-sm">Usa la búsqueda para seleccionar un contribuyente</p>
                </div>
              )}
            </CardContent>
          </Card>
        </div>
      </div>

      {/* Tests Automáticos */}
      <Card>
        <CardHeader>
          <CardTitle className="flex items-center gap-2">
            <TestTube className="h-5 w-5 text-purple-600" />
            Tests Automáticos
          </CardTitle>
        </CardHeader>
        <CardContent className="space-y-4">
          <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
            <div className="text-center p-4 border rounded-lg">
              <div className="flex items-center justify-center mb-2">
                {testResults.rnc ? (
                  <CheckCircle className="h-6 w-6 text-green-600" />
                ) : (
                  <XCircle className="h-6 w-6 text-red-600" />
                )}
              </div>
              <p className="text-sm font-medium">RNC Válido</p>
              <p className="text-xs text-gray-500">131939252</p>
            </div>
            
            <div className="text-center p-4 border rounded-lg">
              <div className="flex items-center justify-center mb-2">
                {testResults.name ? (
                  <CheckCircle className="h-6 w-6 text-green-600" />
                ) : (
                  <XCircle className="h-6 w-6 text-red-600" />
                )}
              </div>
              <p className="text-sm font-medium">Búsqueda por Nombre</p>
              <p className="text-xs text-gray-500">"GRUPO LIS"</p>
            </div>
            
            <div className="text-center p-4 border rounded-lg">
              <div className="flex items-center justify-center mb-2">
                {testResults.spaces ? (
                  <CheckCircle className="h-6 w-6 text-green-600" />
                ) : (
                  <XCircle className="h-6 w-6 text-red-600" />
                )}
              </div>
              <p className="text-sm font-medium">Con Espacios</p>
              <p className="text-xs text-gray-500">"grupo lis digital"</p>
            </div>
            
            <div className="text-center p-4 border rounded-lg">
              <div className="flex items-center justify-center mb-2">
                {testResults.invalid ? (
                  <CheckCircle className="h-6 w-6 text-green-600" />
                ) : (
                  <XCircle className="h-6 w-6 text-red-600" />
                )}
              </div>
              <p className="text-sm font-medium">RNC Inválido</p>
              <p className="text-xs text-gray-500">"123"</p>
            </div>
          </div>
          
          <div className="text-center">
            <Button onClick={runTests} className="px-8">
              <TestTube className="h-4 w-4 mr-2" />
              Ejecutar Tests
            </Button>
          </div>
        </CardContent>
      </Card>

      {/* Información Técnica */}
      <Card>
        <CardHeader>
          <CardTitle className="flex items-center gap-2">
            <Info className="h-5 w-5 text-blue-600" />
            Información Técnica
          </CardTitle>
        </CardHeader>
        <CardContent className="space-y-4">
          <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
            <div>
              <h3 className="font-medium mb-2">🔍 Detección Automática</h3>
              <ul className="text-sm text-gray-600 space-y-1">
                <li>• <strong>9 dígitos:</strong> Búsqueda por RNC</li>
                <li>• <strong>Texto:</strong> Búsqueda por nombre/razón social</li>
                <li>• <strong>Espacios:</strong> Se manejan automáticamente</li>
                <li>• <strong>Caracteres especiales:</strong> Se limpian automáticamente</li>
              </ul>
            </div>
            
            <div>
              <h3 className="font-medium mb-2">🛠️ Funciones Auxiliares</h3>
              <ul className="text-sm text-gray-600 space-y-1">
                <li>• <code>isValidRnc()</code> - Valida formato RNC</li>
                <li>• <code>cleanRnc()</code> - Limpia caracteres especiales</li>
                <li>• <code>formatRnc()</code> - Formato XXX-XXXXX-X</li>
                <li>• <code>getContributorDisplayName()</code> - Nombre legible</li>
              </ul>
            </div>
          </div>
          
          <div className="bg-gray-50 p-4 rounded-lg">
            <h3 className="font-medium mb-2">📡 API Endpoints</h3>
            <div className="text-sm space-y-1">
              <p><strong>RNC:</strong> <code>https://rnc-contributors.vercel.app/api/contributors/rnc/{`{rnc}`}</code></p>
              <p><strong>Nombre:</strong> <code>https://rnc-contributors.vercel.app/api/contributors/name/{`{name}`}?page=1&limit=5</code></p>
            </div>
          </div>
        </CardContent>
      </Card>
    </div>
  )
}
