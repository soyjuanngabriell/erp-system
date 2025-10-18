"use client"

import { useState } from "react"
import { useRouter } from "next/navigation"
import { Button } from "@/components/ui/button"
import { Input } from "@/components/ui/input"
import { Label } from "@/components/ui/label"
import { Textarea } from "@/components/ui/textarea"
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card"
import { useToast } from "@/hooks/use-toast"
import { createClient } from "@/lib/supabase/client"
import { Loader2, Save } from "lucide-react"

interface BusinessConfig {
  id?: string
  business_name: string
  rnc: string
  address: string
  phone: string
  email: string
  logo_url?: string
  low_stock_threshold: number
  fiscal_sequence: number
  governmental_sequence: number
}

interface BusinessConfigFormProps {
  businessConfig?: BusinessConfig | null
}

export function BusinessConfigForm({ businessConfig }: BusinessConfigFormProps) {
  const router = useRouter()
  const { toast } = useToast()
  const [isLoading, setIsLoading] = useState(false)
  const [formData, setFormData] = useState({
    business_name: businessConfig?.business_name || "",
    rnc: businessConfig?.rnc || "",
    address: businessConfig?.address || "",
    phone: businessConfig?.phone || "",
    email: businessConfig?.email || "",
    logo_url: businessConfig?.logo_url || "",
    low_stock_threshold: businessConfig?.low_stock_threshold || 10,
    fiscal_sequence: businessConfig?.fiscal_sequence || 0,
    governmental_sequence: businessConfig?.governmental_sequence || 0,
  })

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault()
    setIsLoading(true)

    try {
      const supabase = createClient()
      const {
        data: { user },
      } = await supabase.auth.getUser()

      if (!user) throw new Error("No autenticado")

      if (businessConfig?.id) {
        // Update existing config
        const { error } = await supabase
          .from("business_config")
          .update({
            business_name: formData.business_name,
            rnc: formData.rnc,
            address: formData.address,
            phone: formData.phone,
            email: formData.email,
            logo_url: formData.logo_url || null,
            low_stock_threshold: formData.low_stock_threshold,
            fiscal_sequence: formData.fiscal_sequence,
            governmental_sequence: formData.governmental_sequence,
            updated_at: new Date().toISOString(),
          })
          .eq("id", businessConfig.id)

        if (error) throw error

        // Sync invoice sequences after updating config
        const { error: syncError } = await supabase.rpc("sync_invoice_sequences_from_config")
        if (syncError) throw syncError
      } else {
        // Create new config
        const { error } = await supabase.from("business_config").insert({
          business_name: formData.business_name,
          rnc: formData.rnc,
          address: formData.address,
          phone: formData.phone,
          email: formData.email,
          logo_url: formData.logo_url || null,
          low_stock_threshold: formData.low_stock_threshold,
          fiscal_sequence: formData.fiscal_sequence,
          governmental_sequence: formData.governmental_sequence,
        })

        if (error) throw error

        // Sync invoice sequences after creating config
        const { error: syncError } = await supabase.rpc("sync_invoice_sequences_from_config")
        if (syncError) throw syncError
      }

      toast({
        title: "Configuración guardada",
        description: "La configuración de la empresa ha sido actualizada exitosamente",
      })

      router.refresh()
    } catch (error) {
      toast({
        title: "Error",
        description: error instanceof Error ? error.message : "Error al guardar la configuración",
        variant: "destructive",
      })
    } finally {
      setIsLoading(false)
    }
  }

  return (
    <form onSubmit={handleSubmit} className="space-y-6">
      <div className="grid gap-4 md:grid-cols-2">
        <div className="space-y-2">
          <Label htmlFor="business_name">Nombre de la Empresa</Label>
          <Input
            id="business_name"
            value={formData.business_name}
            onChange={(e) => setFormData({ ...formData, business_name: e.target.value })}
            placeholder="Mi Empresa SRL"
            required
          />
        </div>

        <div className="space-y-2">
          <Label htmlFor="rnc">RNC</Label>
          <Input
            id="rnc"
            value={formData.rnc}
            onChange={(e) => setFormData({ ...formData, rnc: e.target.value })}
            placeholder="123456789"
            required
          />
        </div>

        <div className="space-y-2">
          <Label htmlFor="phone">Teléfono</Label>
          <Input
            id="phone"
            value={formData.phone}
            onChange={(e) => setFormData({ ...formData, phone: e.target.value })}
            placeholder="(809) 123-4567"
            required
          />
        </div>

        <div className="space-y-2">
          <Label htmlFor="email">Email</Label>
          <Input
            id="email"
            type="email"
            value={formData.email}
            onChange={(e) => setFormData({ ...formData, email: e.target.value })}
            placeholder="empresa@ejemplo.com"
            required
          />
        </div>
      </div>

      <div className="space-y-2">
        <Label htmlFor="address">Dirección</Label>
        <Textarea
          id="address"
          value={formData.address}
          onChange={(e) => setFormData({ ...formData, address: e.target.value })}
          placeholder="Calle Principal #123, Santo Domingo, República Dominicana"
          required
        />
      </div>

      <div className="space-y-2">
        <Label htmlFor="logo_url">URL del Logo (opcional)</Label>
        <Input
          id="logo_url"
          value={formData.logo_url}
          onChange={(e) => setFormData({ ...formData, logo_url: e.target.value })}
          placeholder="https://ejemplo.com/logo.png"
        />
      </div>

      <div className="space-y-2">
        <Label htmlFor="low_stock_threshold">Umbral de Stock Bajo</Label>
        <Input
          id="low_stock_threshold"
          type="number"
          min="1"
          value={formData.low_stock_threshold}
          onChange={(e) => setFormData({ ...formData, low_stock_threshold: parseInt(e.target.value) })}
          required
        />
        <p className="text-sm text-muted-foreground">
          Los productos con stock igual o menor a este número se mostrarán como "stock bajo"
        </p>
      </div>

      <div className="grid gap-4 md:grid-cols-2">
        <div className="space-y-2">
          <Label htmlFor="fiscal_sequence">Secuencia Facturas Valor Fiscal</Label>
          <Input
            id="fiscal_sequence"
            type="number"
            min="0"
            value={formData.fiscal_sequence}
            onChange={(e) => setFormData({ ...formData, fiscal_sequence: parseInt(e.target.value) || 0 })}
            placeholder="0"
          />
          <p className="text-sm text-muted-foreground">
            Número inicial para facturas con valor fiscal (B0100000XXXX)
          </p>
        </div>

        <div className="space-y-2">
          <Label htmlFor="governmental_sequence">Secuencia Facturas Valor Gubernamental</Label>
          <Input
            id="governmental_sequence"
            type="number"
            min="0"
            value={formData.governmental_sequence}
            onChange={(e) => setFormData({ ...formData, governmental_sequence: parseInt(e.target.value) || 0 })}
            placeholder="0"
          />
          <p className="text-sm text-muted-foreground">
            Número inicial para facturas con valor gubernamental (B1500000XXXX)
          </p>
        </div>
      </div>

      <Button type="submit" disabled={isLoading} className="w-full">
        {isLoading ? (
          <>
            <Loader2 className="mr-2 h-4 w-4 animate-spin" />
            Guardando...
          </>
        ) : (
          <>
            <Save className="mr-2 h-4 w-4" />
            Guardar Configuración
          </>
        )}
      </Button>
    </form>
  )
}
