"use client"

import { useState } from "react"
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from "@/components/ui/table"
import { Badge } from "@/components/ui/badge"
import { Button } from "@/components/ui/button"
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select"
import { Eye, Pencil, UserPlus } from "lucide-react"
import Link from "next/link"
import { createClient } from "@/lib/supabase/client"
import { toast } from "sonner"
import { useUsers } from "@/hooks/use-users"
import { useCurrentUser } from "@/hooks/use-current-user"
import { AssignOrderModal } from "@/components/assign-order-modal"

interface Order {
  id: string
  order_number: string
  customer_name: string
  customer_email?: string
  customer_phone?: string
  status: string
  total: number
  created_at: string
  created_by_profile?: {
    full_name: string
    email: string
  }
  assigned_to_profile?: {
    full_name: string
    email: string
  }
  assigned_at?: string
}

interface OrdersTableProps {
  orders: Order[]
}

export function OrdersTable({ orders }: OrdersTableProps) {
  const [assigningOrder, setAssigningOrder] = useState<string | null>(null)
  const supabase = createClient()
  const { users, loading: usersLoading } = useUsers()
  const { user: currentUser } = useCurrentUser()

  const getStatusColor = (status: string) => {
    switch (status) {
      case "Completado":
        return "bg-green-500/10 text-green-500 hover:bg-green-500/20"
      case "En Proceso":
        return "bg-blue-500/10 text-blue-500 hover:bg-blue-500/20"
      case "Pendiente":
        return "bg-yellow-500/10 text-yellow-500 hover:bg-yellow-500/20"
      case "Cancelado":
        return "bg-red-500/10 text-red-500 hover:bg-red-500/20"
      default:
        return ""
    }
  }

  const handleOrderAssigned = () => {
    // Refresh the page to show updated data
    window.location.reload()
  }

  if (orders.length === 0) {
    return <p className="text-center text-muted-foreground py-8">No hay órdenes registradas</p>
  }

  return (
    <div className="rounded-md border">
      <Table>
        <TableHeader>
          <TableRow>
            <TableHead>Número</TableHead>
            <TableHead>Cliente</TableHead>
            <TableHead>Estado</TableHead>
            <TableHead>Creado por</TableHead>
            <TableHead>Asignado a</TableHead>
            <TableHead className="text-right">Total</TableHead>
            <TableHead>Fecha</TableHead>
            <TableHead className="text-right">Acciones</TableHead>
          </TableRow>
        </TableHeader>
        <TableBody>
          {orders.map((order) => (
            <TableRow key={order.id}>
              <TableCell className="font-medium">{order.order_number}</TableCell>
              <TableCell>
                <div>
                  <div className="font-medium">{order.customer_name}</div>
                  {order.customer_email && (
                    <div className="text-sm text-muted-foreground">{order.customer_email}</div>
                  )}
                </div>
              </TableCell>
              <TableCell>
                <Badge variant="secondary" className={getStatusColor(order.status)}>
                  {order.status}
                </Badge>
              </TableCell>
              <TableCell>
                <div className="text-sm">
                  <div className="font-medium">{order.created_by_profile?.full_name || 'N/A'}</div>
                </div>
              </TableCell>
              <TableCell>
                {order.assigned_to_profile ? (
                  <div className="text-sm">
                    <div className="font-medium">{order.assigned_to_profile.full_name}</div>
                    {order.assigned_at && (
                      <div className="text-xs text-muted-foreground">
                        {new Date(order.assigned_at).toLocaleDateString("es-DO")}
                      </div>
                    )}
                  </div>
                ) : order.status === "Pendiente" && currentUser ? (
                  <AssignOrderModal 
                    orderId={order.id} 
                    orderTotal={order.total}
                    onOrderAssigned={handleOrderAssigned}
                  />
                ) : (
                  <span className="text-muted-foreground">No asignado</span>
                )}
              </TableCell>
              <TableCell className="text-right">RD$ {order.total.toLocaleString()}</TableCell>
              <TableCell>{new Date(order.created_at).toLocaleDateString("es-DO")}</TableCell>
              <TableCell className="text-right">
                <div className="flex justify-end gap-2">
                  <Button variant="ghost" size="icon" asChild>
                    <Link href={`/dashboard/orders/${order.id}`}>
                      <Eye className="h-4 w-4" />
                    </Link>
                  </Button>
                  <Button variant="ghost" size="icon" asChild>
                    <Link href={`/dashboard/orders/${order.id}/edit`}>
                      <Pencil className="h-4 w-4" />
                    </Link>
                  </Button>
                </div>
              </TableCell>
            </TableRow>
          ))}
        </TableBody>
      </Table>
    </div>
  )
}
