"use client"

import { Bar, BarChart, CartesianGrid, XAxis, YAxis, Tooltip, ResponsiveContainer } from "recharts"

interface TopProductsChartProps {
  data: Array<{
    name: string
    quantity: number
    revenue: number
  }>
}

export function TopProductsChart({ data }: TopProductsChartProps) {
  if (data.length === 0) {
    return (
      <div className="flex h-[400px] items-center justify-center text-muted-foreground">
        No hay datos de productos para mostrar
      </div>
    )
  }

  const chartData = data.map((item) => ({
    name: item.name.length > 20 ? item.name.substring(0, 20) + "..." : item.name,
    revenue: Math.round(item.revenue),
    quantity: item.quantity,
  }))

  return (
    <ResponsiveContainer width="100%" height={400}>
      <BarChart data={chartData} layout="vertical">
        <CartesianGrid strokeDasharray="3 3" className="stroke-muted" />
        <XAxis type="number" className="text-xs" />
        <YAxis dataKey="name" type="category" width={150} className="text-xs" />
        <Tooltip
          content={({ active, payload }) => {
            if (active && payload && payload.length) {
              return (
                <div className="rounded-lg border bg-background p-2 shadow-sm">
                  <div className="grid gap-2">
                    <div className="flex flex-col">
                      <span className="text-[0.70rem] uppercase text-muted-foreground">Producto</span>
                      <span className="font-bold text-muted-foreground">{payload[0].payload.name}</span>
                    </div>
                    <div className="flex flex-col">
                      <span className="text-[0.70rem] uppercase text-muted-foreground">Ingresos</span>
                      <span className="font-bold">RD$ {payload[0].value?.toLocaleString()}</span>
                    </div>
                    <div className="flex flex-col">
                      <span className="text-[0.70rem] uppercase text-muted-foreground">Cantidad</span>
                      <span className="font-bold">{payload[0].payload.quantity} unidades</span>
                    </div>
                  </div>
                </div>
              )
            }
            return null
          }}
        />
        <Bar dataKey="revenue" fill="hsl(var(--primary))" radius={[0, 4, 4, 0]} />
      </BarChart>
    </ResponsiveContainer>
  )
}
