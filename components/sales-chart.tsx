"use client"

import { Bar, BarChart, CartesianGrid, XAxis, YAxis, Tooltip, ResponsiveContainer } from "recharts"

interface SalesChartProps {
  data: Array<{
    total: number
    created_at: string
  }>
}

export function SalesChart({ data }: SalesChartProps) {
  // Group sales by day
  const salesByDay = new Map<string, number>()

  data.forEach((sale) => {
    const date = new Date(sale.created_at).toLocaleDateString("es-DO", {
      month: "short",
      day: "numeric",
    })
    const existing = salesByDay.get(date) || 0
    salesByDay.set(date, existing + sale.total)
  })

  const chartData = Array.from(salesByDay.entries())
    .map(([date, total]) => ({
      date,
      total: Math.round(total),
    }))
    .slice(-30) // Last 30 days

  if (chartData.length === 0) {
    return (
      <div className="flex h-[300px] items-center justify-center text-muted-foreground">
        No hay datos de ventas para mostrar
      </div>
    )
  }

  return (
    <ResponsiveContainer width="100%" height={300}>
      <BarChart data={chartData}>
        <CartesianGrid strokeDasharray="3 3" className="stroke-muted" />
        <XAxis dataKey="date" className="text-xs" />
        <YAxis className="text-xs" />
        <Tooltip
          content={({ active, payload }) => {
            if (active && payload && payload.length) {
              return (
                <div className="rounded-lg border bg-background p-2 shadow-sm">
                  <div className="grid grid-cols-2 gap-2">
                    <div className="flex flex-col">
                      <span className="text-[0.70rem] uppercase text-muted-foreground">Fecha</span>
                      <span className="font-bold text-muted-foreground">{payload[0].payload.date}</span>
                    </div>
                    <div className="flex flex-col">
                      <span className="text-[0.70rem] uppercase text-muted-foreground">Total</span>
                      <span className="font-bold">RD$ {payload[0].value?.toLocaleString()}</span>
                    </div>
                  </div>
                </div>
              )
            }
            return null
          }}
        />
        <Bar dataKey="total" fill="hsl(var(--primary))" radius={[4, 4, 0, 0]} />
      </BarChart>
    </ResponsiveContainer>
  )
}
