// Program.cs
using Microsoft.Agents.Hosting.AspNetCore;
using Microsoft.Agents.Storage;
using Microsoft.SemanticKernel;
using SkWeatherAgent;
using SkWeatherAgent.Plugins;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddHttpClient();

// Register Semantic Kernel
builder.Services.AddKernel();

// Register AI service — swap UseAzureOpenAI in appsettings to switch provider
if (builder.Configuration.GetSection("AIServices").GetValue<bool>("UseAzureOpenAI"))
{
    builder.Services.AddAzureOpenAIChatCompletion(
        deploymentName: builder.Configuration["AIServices:AzureOpenAI:DeploymentName"]!,
        endpoint: builder.Configuration["AIServices:AzureOpenAI:Endpoint"]!,
        apiKey: builder.Configuration["AIServices:AzureOpenAI:ApiKey"]!);
}
else
{
    builder.Services.AddOpenAIChatCompletion(
        modelId: builder.Configuration["AIServices:OpenAI:ModelId"]!,
        apiKey: builder.Configuration["AIServices:OpenAI:ApiKey"]!);
}

// Register SK plugin and agent
builder.Services.AddSingleton<WeatherPlugin>();
builder.Services.AddSingleton<IStorage, MemoryStorage>();
builder.AddAgentApplicationOptions();
builder.AddAgent<WeatherAgent>();
builder.Services.AddAgentAspNetAuthentication(builder.Configuration);

var app = builder.Build();

app.UseAuthentication();
app.UseAuthorization();
app.MapAgentRootEndpoint();
app.MapAgentApplicationEndpoints(requireAuth: !app.Environment.IsDevelopment());

app.Run();
