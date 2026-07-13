// A deliberately flawed MCP server for eval purposes
// Issues: no annotations, noun-first descriptions, missing parameter .describe(),
// no server instructions, no caching, static data loaded per call, get_ naming,
// resource missing mimeType, template param/URI variable mismatch, completions
// capability undeclared, single-call prompt that should be a tool, dotted tool
// name (Claude API portability), missing icon metadata

import { McpServer, ResourceTemplate } from "@modelcontextprotocol/sdk/server/mcp.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import { z } from "zod";
import { readFileSync } from "fs";

// PLANTED BUG (T5b): missing icon metadata
// No registered tool, resource, template, or prompt in this file declares an `icons`
// array (SEP-973), and there is no icon.svg at the repo root for Smithery's icon
// category. Absence-type bug: nothing here to rename, the gap is that no icon
// metadata exists anywhere in this server.
const server = new McpServer({ name: "recipe-finder", version: "0.1.0" });

server.registerTool(
  "get_recipes",
  {
    description: "This tool is for getting recipes from our database",
    inputSchema: {
      cuisine: z.string().optional(),
      maxTime: z.number().optional(),
    },
  },
  async ({ cuisine, maxTime }) => {
    // Bad: reads file on every call
    const recipes = JSON.parse(readFileSync("data/recipes.json", "utf-8"));
    const filtered = recipes.filter((r: any) => {
      if (cuisine && r.cuisine !== cuisine) return false;
      if (maxTime && r.prepTime > maxTime) return false;
      return true;
    });
    return { content: [{ type: "text", text: JSON.stringify(filtered) }] };
  }
);

server.registerTool(
  "get_recipe_detail",
  {
    description: "Recipe detail information",
    inputSchema: {
      id: z.string(),
    },
  },
  async ({ id }) => {
    // Bad: reads file on every call, no try/catch
    const recipes = JSON.parse(readFileSync("data/recipes.json", "utf-8"));
    const recipe = recipes.find((r: any) => r.id === id);
    if (!recipe) throw new Error("Recipe not found");
    return { content: [{ type: "text", text: JSON.stringify(recipe) }] };
  }
);

// PLANTED BUG (T5a): dotted tool name breaks Claude API
server.registerTool(
  "recipes.search",
  {
    description: "Allows searching for recipes using ingredient names as search terms",
    inputSchema: {
      ingredients: z.array(z.string()),
      matchAll: z.boolean().optional(),
    },
  },
  async ({ ingredients, matchAll }) => {
    // Bad: reads file on every call, no error handling
    const recipes = JSON.parse(readFileSync("data/recipes.json", "utf-8"));
    const results = recipes.filter((r: any) => {
      const recipeIngredients = r.ingredients.map((i: any) => i.name.toLowerCase());
      if (matchAll) {
        return ingredients.every(ing => recipeIngredients.includes(ing.toLowerCase()));
      }
      return ingredients.some(ing => recipeIngredients.includes(ing.toLowerCase()));
    });
    return { content: [{ type: "text", text: JSON.stringify(results) }] };
  }
);

// Bad: JSON resource but no mimeType declared anywhere — clients can't tell
// this content isn't plain text
// PLANTED BUG (T2): json resource missing mimeType
server.registerResource(
  "cuisines",
  "recipes://cuisines",
  {
    title: "Available Cuisines",
    description: "List of cuisine categories in the recipe database",
  },
  async (uri) => ({
    contents: [
      {
        uri: uri.href,
        text: JSON.stringify(["italian", "thai", "mexican", "japanese", "indian"]),
      },
    ],
  })
);

// PLANTED BUG (T3a): template param/URI variable mismatch
server.registerResource(
  "cuisine-recipes",
  new ResourceTemplate("recipes://cuisine/{cuisineSlug}", { list: undefined }),
  {
    title: "Recipes by Cuisine",
    description: "All recipes in one cuisine category",
    mimeType: "application/json",
  },
  async (uri, { cuisine }) => {
    // Bad: `cuisine` is always undefined, the URI template variable is `cuisineSlug`
    const recipes = JSON.parse(readFileSync("data/recipes.json", "utf-8"));
    const filtered = recipes.filter((r: any) => r.cuisine === cuisine);
    return {
      contents: [
        { uri: uri.href, mimeType: "application/json", text: JSON.stringify(filtered) },
      ],
    };
  }
);

// PLANTED BUG (T3b): complete map key mismatches URI variable, completions never enabled
server.registerResource(
  "ingredient-info",
  new ResourceTemplate("recipes://ingredient/{ingredientName}", {
    list: undefined,
    complete: {
      // Bad: key must match the URI template variable exactly ("ingredientName"),
      // so this callback never fires and the completions capability never gets declared
      ingredient: async (value: string) => {
        const names = ["basil", "garlic", "ginger", "chili", "turmeric"];
        return names.filter((n) => n.startsWith(value.toLowerCase()));
      },
    },
  }),
  {
    title: "Ingredient Info",
    description: "Substitution and pairing notes for one ingredient",
    mimeType: "application/json",
  },
  async (uri, { ingredientName }) => {
    const info: Record<string, string> = {
      basil: "Pairs with tomato and mozzarella; substitute with oregano.",
      garlic: "Pairs with ginger and chili; substitute with garlic powder.",
    };
    return {
      contents: [
        {
          uri: uri.href,
          mimeType: "application/json",
          text: JSON.stringify(info[ingredientName] ?? null),
        },
      ],
    };
  }
);

// PLANTED BUG (T4): single-call prompt that should be a tool
server.registerPrompt(
  "recipe_detail_prompt",
  {
    description: "Prompt for recipe detail",
    argsSchema: {
      id: z.string(),
    },
  },
  ({ id }) => ({
    // Bad: this is one tool call with the argument passed straight through,
    // no chaining, no workflow, and the description is vague/noun-first
    messages: [
      {
        role: "user",
        content: { type: "text", text: `Call get_recipe_detail with id ${id}.` },
      },
    ],
  })
);

const transport = new StdioServerTransport();
await server.connect(transport);
