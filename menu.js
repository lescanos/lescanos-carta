// Fuente de verdad del menú — compartido por index.html y litzy.html.
// Para actualizar precios, usar la vista admin de index.html (guarda en localStorage).
const DEFAULT_CARTA = [
  {
    pagina:"1", titulo:"Hamburguesas",
    secciones:[{
      emoji:"🍔", titulo:"HAMBURGUESAS",
      nota:"Con papas y gaseosa de vidrio",
      columnas:["Solo","Con papas"],
      items:[
        {nombre:"Elmer Fudd",     desc:"Mayonesa, medallón 120g, queso, lechuga, tomate",                                   precios:["$0","$0"]},
        {nombre:"Tweety",         desc:"Kétchup, cebolla caramelizada, medallón 120g, panceta, cheddar",                    precios:["$0","$0"]},
        {nombre:"Marvin",         desc:"Mostaza, guacamole, pepinillo, cheddar, dos medallones 120g",                       precios:["$0","$0"]},
        {nombre:"Lescano",        desc:"Mayonesa, dos medallones 120g, jamón, queso, huevo frito, panceta (papas cheddar)", precios:["$0","$0"]},
        {nombre:"Porky",          desc:"Kétchup, cebolla, dos medallones 120g, cheddar, panceta, bañada en cheddar",        precios:["$0","$0"]},
        {nombre:"Taz",            desc:"Mostaza, tres medallones 120g, cheddar, panceta, cebolla morada, lechuga, tomate",  precios:["$0","$0"]},
      ]
    }]
  },
  {
    pagina:"2", titulo:"Panchos & Milanesas",
    secciones:[
      {
        emoji:"🌭", titulo:"PANCHOS",
        nota:"Solo o con papas",
        columnas:["Solo","Con papas"],
        items:[
          {nombre:"Lola Bunny", desc:"Mayonesa, kétchup, papitas",                         precios:["$0","$0"]},
          {nombre:"Bugs Bunny", desc:"Cebolla caramelizada, papitas, mostaza, queso",       precios:["$0","$0"]},
          {nombre:"Lucas",      desc:"Mayonesa, cheddar, jamón, queso, huevo, papitas",     precios:["$0","$0"]},
        ]
      },
      {
        emoji:"🥩", titulo:"MILANESAS / SUPREMAS",
        nota:"Con papas",
        columnas:["Solo","Con papas"],
        items:[
          {nombre:"Abuelita",   desc:"Mayonesa, mostaza, lechuga, tomate",                              precios:["$0","$0"]},
          {nombre:"San Bigotes",desc:"Kétchup, cebolla caramelizada, queso, tomate",                    precios:["$0","$0"]},
          {nombre:"Silvestre",  desc:"Mayonesa, cebolla con ají, jamón, queso, huevo, lechuga, tomate", precios:["$0","$0"]},
          {nombre:"Lescano",    desc:"Mayonesa, cheddar, huevo, jamón, queso, panceta",                 precios:["$0","$0"]},
        ]
      }
    ]
  },
  {
    pagina:"3", titulo:"Pizzas & Pizzanesas",
    secciones:[
      {
        emoji:"🍕", titulo:"PIZZAS",
        nota:"Media o entera",
        columnas:["Media","Entera"],
        items:[
          {nombre:"Común",      desc:"Salsa, muzzarella, aceitunas",                                                precios:["$0","$0"]},
          {nombre:"Especial",   desc:"Salsa, jamón, muzzarella, morrón, huevo duro, aceitunas",                     precios:["$0","$0"]},
          {nombre:"Roquefort",  desc:"Salsa, muzzarella, roquefort",                                                precios:["$0","$0"]},
          {nombre:"Napolitana", desc:"Salsa, muzzarella, orégano, ajo, tomate",                                     precios:["$0","$0"]},
          {nombre:"Cantimpalo", desc:"Salsa, muzzarella, cantimpalo",                                               precios:["$0","$0"]},
          {nombre:"Fugazza",    desc:"Salsa, cebolla, muzzarella",                                                  precios:["$0","$0"]},
          {nombre:"Anchoas",    desc:"Salsa, muzzarella, anchoas",                                                  precios:["$0","$0"]},
          {nombre:"Pollo",      desc:"Salsa, pollo con salsa blanca, muzzarella",                                   precios:["$0","$0"]},
          {nombre:"Lescano",    desc:"Salsa, pollo con salsa blanca, jamón, muzzarella, huevo frito, panceta, cheddar", precios:["$0","$0"]},
        ]
      },
      {
        emoji:"🍕", titulo:"PIZZANESAS",
        nota:"Con papas fritas",
        columnas:["1 pers","2 pers","3 pers"],
        items:[
          {nombre:"Común",      desc:"Salsa, muzzarella, aceitunas",                          precios:["$0","$0","$0"]},
          {nombre:"Napolitana", desc:"Salsa, jamón, muzzarella, tomate, orégano, ajo",         precios:["$0","$0","$0"]},
          {nombre:"Roquefort",  desc:"Salsa, muzzarella, roquefort",                           precios:["$0","$0","$0"]},
          {nombre:"Lescano",    desc:"Salsa, jamón, muzzarella, huevo frito, panceta, cheddar",precios:["$0","$0","$0"]},
        ]
      }
    ]
  },
  {
    pagina:"4", titulo:"Torpedos & Carlitos",
    secciones:[
      {
        emoji:"🥖", titulo:"TORPEDOS",
        nota:"Solo o con papas",
        items:[
          {nombre:"Común",      desc:"Mayonesa, jamón, queso, lechuga, tomate",                                                   precio:"$0"},
          {nombre:"Hamburguesa",desc:"Mayonesa, tres medallones 120g, jamón, queso, lechuga, tomate",                             precio:"$0"},
          {nombre:"Lescano",    desc:"Mayonesa, suprema/milanesa, jamón, queso, huevo, cheddar, panceta, lechuga, tomate",        precio:"$0"},
        ]
      },
      {
        emoji:"🥪", titulo:"CARLITOS / TOSTADOS",
        nota:"",
        items:[
          {nombre:"Común (simple)",         desc:"Aderezo, jamón, queso",                                      precio:"$0"},
          {nombre:"Especial (triple)",       desc:"Aderezo, jamón, queso, huevo, aceitunas, morrón",            precio:"$0"},
          {nombre:"Carne mechada (triple)",  desc:"Aderezo, jamón, queso, carne mechada",                       precio:"$0"},
          {nombre:"Lescano (triple)",        desc:"Aderezo, cheddar, jamón, queso, huevo frito, pollo, panceta",precio:"$0"},
        ]
      }
    ]
  },
  {
    pagina:"5", titulo:"Guarniciones & Bebidas",
    secciones:[
      {
        emoji:"🍟", titulo:"GUARNICIONES",
        nota:"",
        items:[
          {nombre:"Papas fritas",                    desc:"Porción individual",precio:"$0"},
          {nombre:"Papas fritas cheddar y panceta",  desc:"Porción individual",precio:"$0"},
        ]
      },
      {
        emoji:"🥤", titulo:"BEBIDAS SIN ALCOHOL",
        nota:"",
        items:[
          {nombre:"Gaseosa 500ml",        desc:"",precio:"$0"},
          {nombre:"Agua 500ml",           desc:"",precio:"$0"},
          {nombre:"Agua saborizada 500ml",desc:"",precio:"$0"},
          {nombre:"Gaseosa 1,25L",        desc:"",precio:"$0"},
        ]
      },
      {
        emoji:"🍺", titulo:"CERVEZAS",
        nota:"",
        items:[
          {nombre:"Lata Isenbeck 473cc",desc:"",precio:"$0"},
          {nombre:"Lata Schneider 710cc",desc:"",precio:"$0"},
          {nombre:"Quilmes 1lt",        desc:"",precio:"$0"},
          {nombre:"Stella 1lt",         desc:"",precio:"$0"},
        ]
      },
      {
        emoji:"🍹", titulo:"TRAGOS",
        nota:"",
        items:[
          {nombre:"Fernet",                    desc:"",precio:"$0"},
          {nombre:"Gancia con Sprite y limón", desc:"",precio:"$0"},
          {nombre:"Gin tonic de frutos rojos", desc:"",precio:"$0"},
          {nombre:"Destornillador",            desc:"",precio:"$0"},
          {nombre:"Amargo obrero",             desc:"",precio:"$0"},
        ]
      }
    ]
  },
  {
    pagina:"6", titulo:"Promos",
    tipo:"promos",
    subtitulo:"Viernes, Sábado y Domingo",
    secciones:[],
    items:[
      {nombre:"Pizza Especial + Pizza de Muzza",                       precio:"$25.000"},
      {nombre:"Dos Pizzas de Muzza",                                   precio:"$22.000"},
      {nombre:"Pizza de Muzza + Carlito Común + Cono de Papas",        precio:"$24.000"},
    ]
  }
];
