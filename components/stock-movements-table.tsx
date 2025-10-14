"use client"

import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from "@/components/ui/table"
import { Badge } from "@/components/ui/badge"
import { ArrowUp, ArrowDown, RefreshCw } from "lucide-react"

interface StockMovement {
  id: string
  quantity: number
  type: string
  reason: string | null
  created_at: string
  products: {
    name: string
    sku: string
  }
}

interface StockMovementsTableProps {
  movements: StockMovement[]
}

export function StockMovementsTable({ movements }: StockMovementsTableProps) {
  const getTypeIcon = (type: string) => {
    switch (type) {
      case "entrada":
        return <ArrowUp className="h-4 w-4 text-green-500" />
      case "salida":
        return <ArrowDown className="h-4 w-4 text-red-500" />
      case "ajuste":
        return <RefreshCw className="h-4 w-4 text-blue-500" />
      default:
        return null
    }
  }

  const getTypeColor = (type: string) => {
    switch (type) {
      case "entrada":
        return "bg-green-500/10 text-green-500 hover:bg-green-500/20"
      case "salida":
        return "bg-red-500/10 text-red-500 hover:bg-red-500/20"
      case "ajuste":
        return "bg-blue-500/10 text-blue-500 hover:bg-blue-500/20"
      default:
        return ""
    }
  }

  if (movements.length === 0) {
    return <p className="text-center text-muted-foreground py-8">No hay movimientos registrados</p>
  }

  return (
    <div className="rounded-md border">
      <Table>
        <TableHeader>
          <TableRow>
            <TableHead>Producto</TableHead>
            <TableHead>SKU</TableHead>
            <TableHead>Tipo</TableHead>
            <TableHead className="text-right">Cantidad</TableHead>
            <TableHead>Razón</TableHead>
            <TableHead>Fecha</TableHead>
          </TableRow>
        </TableHeader>
        <TableBody>
          {movements.map((movement) => (
            <TableRow key={movement.id}>
              <TableCell className="font-medium">{movement.products.name}</TableCell>
              <TableCell>{movement.products.sku}</TableCell>
              <TableCell>
                <Badge variant="secondary" className={getTypeColor(movement.type)}>
                  <span className="flex items-center gap-1">
                    {getTypeIcon(movement.type)}
                    {movement.type}
                  </span>
                </Badge>
              </TableCell>
              <TableCell className="text-right font-medium">
                {movement.type === "entrada" ? "+" : movement.type === "salida" ? "-" : ""}
                {Math.abs(movement.quantity)}
              </TableCell>
              <TableCell>{movement.reason || "-"}</TableCell>
              <TableCell>{new Date(movement.created_at).toLocaleString("es-DO")}</TableCell>
            </TableRow>
          ))}
        </TableBody>
      </Table>
    </div>
  )
}
