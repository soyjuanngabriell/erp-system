"use client"

import { useState, useEffect } from "react"
import { useRouter } from "next/navigation"
import { createClient } from "@/lib/supabase/client"
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card"
import { Button } from "@/components/ui/button"
import { ArrowLeft, CheckCircle } from "lucide-react"
import Link from "next/link"
import { toast } from "sonner"

interface Order {
  id: string
  order_number: string
  customer_name: string
  total: number
  deposit_amount: number
  assigned_to_profile?: {
    full_name: string
  }
}

export default function MarkPaidPage({ 
  params 
}: { 
  params: Promise<{ id: string }> 
}) {
  const [order, setOrder] = useState<Order | null>(null)
  const [loading, setLoading] = useState(true)
  const [marking, setMarking] = useState(false)
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
            assigned_to_profile:profiles!orders_assigned_to_fkey(full_name)
          `)
          .eq("id", id)
          .eq("status", "Completado")
          .eq("payment_status", "partial")
          .single()

        if (error) {
          console.error("Error fetching order:", error)
          toast.error("Error al cargar la orden")
          router.push("/dashboard/billing")
          return
        }

        if (!data) {
          toast.error("Orden no encontrada o no elegible")
          router.push("/dashboard/billing")
          return
        }

        setOrder(data)
      } catch (error) {
        console.error("Error:", error)
        toast.error("Error al cargar la orden")
        router.push("/dashboard/billing")
      } finally {
        setLoading(false)
      }
    }

    fetchOrder()
  }, [params, supabase, router])

  const handleMarkAsPaid = async () => {
    if (!order) return

    setMarking(true)
    try {
      const { error } = await supabase
        .from("orders")
        .update({
          payment_status: "paid",
          deposit_amount: order.total,
          deposit_percentage: 100,
          updated_at: new Date().toISOString()
        })
        .eq("id", order.id)

      if (error) {
        throw error
      }

      toast.success("Orden marcada como pagada completamente")
      router.push("/dashboard/billing")
    } catch (error) {
      console.error("Error marking order as paid:", error)
      toast.error("Error al marcar la orden como pagada")
    } finally {
      setMarking(false)
    }
  }

  const formatCurrency = (amount: number) => {
    return new Intl.NumberFormat('es-DO', {
      style: 'currency',
      currency: 'DOP',
      minimumFractionDigits: 2
    }).format(amount)
  }

  if (loading) {
    return (
      <div className="space-y-6">
        <div className="flex items-center gap-4">
          <Button variant="ghost" size="icon" asChild>
            <Link href="/dashboard/billing">
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
            <Link href="/dashboard/billing">
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

  const remainingAmount = order.total - (order.deposit_amount || 0)

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <div className="flex items-center gap-4">
          <Button variant="ghost" size="icon" asChild>
            <Link href="/dashboard/billing">
              <ArrowLeft className="h-4 w-4" />
            </Link>
          </Button>
          <div>
            <h1 className="text-3xl font-bold">Marcar como Pagado</h1>
            <p className="text-muted-foreground">Orden #{order.order_number}</p>
          </div>
        </div>
      </div>

      <div className="grid gap-6 md:grid-cols-2">
        <Card>
          <CardHeader>
            <CardTitle>Información de la Orden</CardTitle>
          </CardHeader>
          <CardContent className="space-y-4">
            <div>
              <p className="text-sm font-medium text-muted-foreground">Número de Orden</p>
              <p className="text-lg font-semibold">#{order.order_number}</p>
            </div>
            <div>
              <p className="text-sm font-medium text-muted-foreground">Cliente</p>
              <p className="text-lg font-semibold">{order.customer_name}</p>
            </div>
            <div>
              <p className="text-sm font-medium text-muted-foreground">Asignado a</p>
              <p className="text-lg font-semibold">{order.assigned_to_profile?.full_name || 'N/A'}</p>
            </div>
          </CardContent>
        </Card>

        <Card>
          <CardHeader>
            <CardTitle>Resumen de Pagos</CardTitle>
          </CardHeader>
          <CardContent className="space-y-4">
            <div className="space-y-2">
              <div className="flex justify-between">
                <span>Total de la Orden:</span>
                <span className="font-semibold">{formatCurrency(order.total)}</span>
              </div>
              <div className="flex justify-between">
                <span>Abono Recibido:</span>
                <span className="font-semibold text-green-600">{formatCurrency(order.deposit_amount || 0)}</span>
              </div>
              <div className="flex justify-between border-t pt-2">
                <span className="font-bold">Pendiente de Pago:</span>
                <span className="font-bold text-red-600">{formatCurrency(remainingAmount)}</span>
              </div>
            </div>
          </CardContent>
        </Card>
      </div>

      <Card>
        <CardHeader>
          <CardTitle className="flex items-center gap-2">
            <CheckCircle className="h-5 w-5 text-green-500" />
            Confirmar Pago Completo
          </CardTitle>
        </CardHeader>
        <CardContent>
          <div className="space-y-4">
            <p className="text-muted-foreground">
              Al marcar esta orden como pagada completamente, se moverá de la lista de órdenes con abono parcial 
              a la lista de órdenes pagadas completamente.
            </p>
            <div className="flex justify-end gap-4">
              <Button variant="outline" asChild>
                <Link href="/dashboard/billing">Cancelar</Link>
              </Button>
              <Button 
                onClick={handleMarkAsPaid} 
                disabled={marking}
                className="bg-green-600 hover:bg-green-700"
              >
                <CheckCircle className="mr-2 h-4 w-4" />
                {marking ? "Marcando..." : "Marcar como Pagado"}
              </Button>
            </div>
          </div>
        </CardContent>
      </Card>
    </div>
  )
}
