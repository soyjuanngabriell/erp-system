"use client"

import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from "@/components/ui/table"
import { Badge } from "@/components/ui/badge"
import { Button } from "@/components/ui/button"
import { Eye, Pencil } from "lucide-react"
import Link from "next/link"

interface Order {
  id: string
  order_number: string
  customer_name: string
  status: string
  total: number
  created_at: string
}

interface OrdersTableProps {
  orders: Order[]
}

export function OrdersTable({ orders }: OrdersTableProps) {
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
            <TableHead className="text-right">Total</TableHead>
            <TableHead>Fecha</TableHead>
            <TableHead className="text-right">Acciones</TableHead>
          </TableRow>
        </TableHeader>
        <TableBody>
          {orders.map((order) => (
            <TableRow key={order.id}>
              <TableCell className="font-medium">{order.order_number}</TableCell>
              <TableCell>{order.customer_name}</TableCell>
              <TableCell>
                <Badge variant="secondary" className={getStatusColor(order.status)}>
                  {order.status}
                </Badge>
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
