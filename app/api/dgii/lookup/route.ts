import { NextResponse } from "next/server"

export async function POST(request: Request) {
  try {
    const { rnc } = await request.json()

    if (!rnc) {
      return NextResponse.json({ success: false, error: "RNC es requerido" }, { status: 400 })
    }

    // DGII API endpoint for RNC lookup
    // Note: This is a simplified implementation. The actual DGII API may require authentication
    // and have different endpoints. This uses web scraping as a fallback.
    const response = await fetch(`https://dgii.gov.do/app/WebApps/ConsultasWeb/consultas/rnc.aspx`, {
      method: "POST",
      headers: {
        "Content-Type": "application/x-www-form-urlencoded",
      },
      body: new URLSearchParams({
        txtRNC: rnc,
      }),
    })

    if (!response.ok) {
      throw new Error("Error al consultar DGII")
    }

    const html = await response.text()

    // Parse the HTML response to extract the company name
    // This is a simplified parser - in production, you'd want more robust parsing
    const nameMatch = html.match(/<span id="lblNombre">([^<]+)<\/span>/i)
    const statusMatch = html.match(/<span id="lblEstado">([^<]+)<\/span>/i)

    if (nameMatch && nameMatch[1]) {
      return NextResponse.json({
        success: true,
        data: {
          rnc,
          name: nameMatch[1].trim(),
          status: statusMatch ? statusMatch[1].trim() : "Desconocido",
        },
      })
    }

    return NextResponse.json(
      {
        success: false,
        error: "RNC no encontrado",
      },
      { status: 404 },
    )
  } catch (error) {
    console.error("[v0] DGII lookup error:", error)
    return NextResponse.json(
      {
        success: false,
        error: "Error al consultar DGII",
      },
      { status: 500 },
    )
  }
}
