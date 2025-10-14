"use client"

import { useState, useEffect } from "react"
import { useRouter } from "next/navigation"
import { createClient } from "@/lib/supabase/client"
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card"
import { Button } from "@/components/ui/button"
import { Input } from "@/components/ui/input"
import { Label } from "@/components/ui/label"
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select"
import { Textarea } from "@/components/ui/textarea"
import { ArrowLeft, Save } from "lucide-react"
import Link from "next/link"
import { toast } from "sonner"

interface Order {
  id: string
  order_number: string
  customer_name: string
  customer_email?: string
  customer_phone?: string
  status: string
  total: number
  subtotal: number
  tax: number
  discount: number
  notes?: string
  created_at: string
  order_items: Array<{
    id: string
    product_name: string
    quantity: number
    unit_price: number
    total: number
  }>
}

export default function EditOrderPage({ 
  params 
}: { 
  params: Promise<{ id: string }> 
}) {
  const [order, setOrder] = useState<Order | null>(null)
  const [loading, setLoading] = useState(true)
  const [saving, setSaving] = useState(false)
  const router = useRouter()
  const supabase = createClient()

  useEffect(() => {
    async function fetchOrder() {
      try {
        const { id } = await params
        const { data, error } = await supabase
          .from("orders")
          .select(`
            *,
            order_items (*)
          `)
          .eq("id", id)
          .single()

        if (error) {
          console.error("Error fetching order:", error)
          toast.error("Error al cargar la orden")
          return
        }

        if (!data) {
          toast.error("Orden no encontrada")
          router.push("/dashboard/orders")
          return
        }

        setOrder(data)
      } catch (error) {
        console.error("Error:", error)
        toast.error("Error al cargar la orden")
      } finally {
        setLoading(false)
      }
    }

    fetchOrder()
  }, [params, supabase, router])

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault()
    if (!order) return

    setSaving(true)
    try {
      const { error } = await supabase
        .from("orders")
        .update({
          customer_name: order.customer_name,
          customer_email: order.customer_email,
          customer_phone: order.customer_phone,
          status: order.status,
          notes: order.notes,
          updated_at: new Date().toISOString()
        })
        .eq("id", order.id)

      if (error) {
        console.error("Error updating order:", error)
        toast.error("Error al actualizar la orden")
        return
      }

      toast.success("Orden actualizada exitosamente")
      router.push(`/dashboard/orders/${order.id}`)
    } catch (error) {
      console.error("Error:", error)
      toast.error("Error al actualizar la orden")
    } finally {
      setSaving(false)
    }
  }

  if (loading) {
    return (
      <div className="space-y-6">
        <div className="flex items-center gap-4">
          <Button variant="ghost" size="icon" asChild>
            <Link href="/dashboard/orders">
              <ArrowLeft className="h-4 w-4" />
            </Link>
          </Button>
          <div>
            <h1 className="text-3xl font-bold">Cargando...</h1>
          </div>
        </div>
      </div>
    )
  }

  if (!order) {
    return (
      <div className="space-y-6">
        <div className="flex items-center gap-4">
          <Button variant="ghost" size="icon" asChild>
            <Link href="/dashboard/orders">
              <ArrowLeft className="h-4 w-4" />
            </Link>
          </Button>
          <div>
            <h1 className="text-3xl font-bold">Orden no encontrada</h1>
          </div>
        </div>
      </div>
    )
  }

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <div className="flex items-center gap-4">
          <Button variant="ghost" size="icon" asChild>
            <Link href={`/dashboard/orders/${order.id}`}>
              <ArrowLeft className="h-4 w-4" />
            </Link>
          </Button>
          <div>
            <h1 className="text-3xl font-bold">Editar Orden #{order.order_number}</h1>
            <p className="text-muted-foreground">Modifica los detalles de la orden</p>
          </div>
        </div>
      </div>

      <form onSubmit={handleSubmit} className="space-y-6">
        <div className="grid gap-6 md:grid-cols-2">
          {/* Order Information */}
          <Card>
            <CardHeader>
              <CardTitle>Información de la Orden</CardTitle>
            </CardHeader>
            <CardContent className="space-y-4">
              <div className="space-y-2">
                <Label htmlFor="order_number">Número de Orden</Label>
                <Input
                  id="order_number"
                  value={order.order_number}
                  disabled
                  className="bg-muted"
                />
              </div>
              <div className="space-y-2">
                <Label htmlFor="status">Estado</Label>
                <Select
                  value={order.status}
                  onValueChange={(value) => setOrder({ ...order, status: value })}
                >
                  <SelectTrigger>
                    <SelectValue />
                  </SelectTrigger>
                  <SelectContent>
                    <SelectItem value="Pendiente">Pendiente</SelectItem>
                    <SelectItem value="En Proceso">En Proceso</SelectItem>
                    <SelectItem value="Completado">Completado</SelectItem>
                    <SelectItem value="Cancelado">Cancelado</SelectItem>
                  </SelectContent>
                </Select>
              </div>
              <div className="space-y-2">
                <Label htmlFor="notes">Notas</Label>
                <Textarea
                  id="notes"
                  value={order.notes || ""}
                  onChange={(e) => setOrder({ ...order, notes: e.target.value })}
                  placeholder="Notas adicionales..."
                  rows={3}
                />
              </div>
            </CardContent>
          </Card>

          {/* Customer Information */}
          <Card>
            <CardHeader>
              <CardTitle>Información del Cliente</CardTitle>
            </CardHeader>
            <CardContent className="space-y-4">
              <div className="space-y-2">
                <Label htmlFor="customer_name">Nombre del Cliente</Label>
                <Input
                  id="customer_name"
                  value={order.customer_name}
                  onChange={(e) => setOrder({ ...order, customer_name: e.target.value })}
                  required
                />
              </div>
              <div className="space-y-2">
                <Label htmlFor="customer_email">Email</Label>
                <Input
                  id="customer_email"
                  type="email"
                  value={order.customer_email || ""}
                  onChange={(e) => setOrder({ ...order, customer_email: e.target.value })}
                />
              </div>
              <div className="space-y-2">
                <Label htmlFor="customer_phone">Teléfono</Label>
                <Input
                  id="customer_phone"
                  value={order.customer_phone || ""}
                  onChange={(e) => setOrder({ ...order, customer_phone: e.target.value })}
                />
              </div>
            </CardContent>
          </Card>
        </div>

        {/* Order Summary (Read-only) */}
        <Card>
          <CardHeader>
            <CardTitle>Resumen de la Orden</CardTitle>
          </CardHeader>
          <CardContent>
            <div className="space-y-2">
              <div className="flex justify-between">
                <span>Subtotal:</span>
                <span>RD$ {order.subtotal.toLocaleString()}</span>
              </div>
              {order.discount > 0 && (
                <div className="flex justify-between">
                  <span>Descuento:</span>
                  <span>-RD$ {order.discount.toLocaleString()}</span>
                </div>
              )}
              <div className="flex justify-between">
                <span>Impuestos:</span>
                <span>RD$ {order.tax.toLocaleString()}</span>
              </div>
              <div className="flex justify-between text-lg font-semibold border-t pt-2">
                <span>Total:</span>
                <span>RD$ {order.total.toLocaleString()}</span>
              </div>
            </div>
          </CardContent>
        </Card>

        {/* Action Buttons */}
        <div className="flex justify-end gap-4">
          <Button type="button" variant="outline" asChild>
            <Link href={`/dashboard/orders/${order.id}`}>Cancelar</Link>
          </Button>
          <Button type="submit" disabled={saving}>
            <Save className="mr-2 h-4 w-4" />
            {saving ? "Guardando..." : "Guardar Cambios"}
          </Button>
        </div>
      </form>
    </div>
  )
}
