```
ooooo                                      oooo  oooo              
`888'                                      `888  `888              
 888          .ooooo.   .ooooo.   .oooo.    888   888  oooo    ooo 
 888         d88' `88b d88' `"Y8 `P  )88b   888   888   `88.  .8'
 888         888   888 888        .oP"888   888   888    `88..8'
 888       o 888   888 888   .o8 d8(  888   888   888     `888'
o888ooooood8 `Y8bod8P' `Y8bod8P' `Y888""8o o888o o888o     .8'
                                                       .o..P'
                                                       `Y8P'
```

# Example: Run a MassTransit saga on App Service with Service Bus and Redis within Locally

This example shows how to run two .NET apps on App Service that talk to each other through [MassTransit](https://masstransit.io) over Azure Service Bus, with a saga whose state lives in Azure Cache for Redis, on [Locally Build](https://locally.build). Each app authenticates to Service Bus with its own **user-assigned managed identity**, so neither stores a Service Bus key or connection string. Redis signs them in with the same identities by default, or with an access key if you set `redis_authentication = "access-key"`.

```
 web (App Service)                                    worker (App Service)
   │                                                    │
   ├─ publish OrderSubmitted ─▶ topic ─▶ subscription ─▶ order-state queue ─▶ OrderStateMachine (saga)
   │                                                    │      │   state ◀──▶ Azure Cache for Redis
   │                                                    │      └─ publish FulfilOrder
   │                                                    │
   │                                                    ├─ fulfil-order queue ─▶ FulfilOrderConsumer
   │                                                    │      └─ publish OrderFulfilled ─▶ saga: Fulfilled
   │                                                    │         (or, after 3 retries, Fault<FulfilOrder> ─▶ saga: Faulted)
   │                                                    │
   ├─ request GetOrderStatus ─────────────────────────▶ saga responds ─▶ web's temporary reply queue
   └─ recent order IDs ◀──▶ Azure Cache for Redis (StackExchange.Redis)
```

Both apps are written in C# on ASP.NET Core (.NET 10). They run from one image, and the `ROLE` app setting decides which one a container runs as. The source lives in [`tombuildsstuff/app-service-masstransit`](https://github.com/tombuildsstuff/app-service-masstransit), and the image is published to Docker Hub as [`tombuildsstuff/app-service-masstransit`](https://hub.docker.com/r/tombuildsstuff/app-service-masstransit). This repository is just the infrastructure that runs it.

* **web** is a page where you place orders. Placing one publishes an `OrderSubmitted` event. The page lists recent orders and refreshes every couple of seconds, asking the saga for each order's status over MassTransit's request/response.
* **worker** hosts the **order saga** (a MassTransit state machine) and the **fulfilment consumer**. The saga starts when an order is submitted and asks for the order to be fulfilled. It then moves to `Fulfilled` or `Faulted` depending on what happens. Order an item with `fail` in its name to see the failure path.

## The NuGet packages

| Package | What it does here |
| --- | --- |
| [`MassTransit.Azure.ServiceBus.Core`](https://www.nuget.org/packages/MassTransit.Azure.ServiceBus.Core) | Runs MassTransit over Service Bus. It creates the queues, topics and subscriptions when the apps start, and handles publish/subscribe, retries, error queues and request/response. |
| [`MassTransit.Redis`](https://www.nuget.org/packages/MassTransit.Redis) | Saga repository: stores each saga instance in Redis, with optimistic concurrency. |
| [`StackExchange.Redis`](https://www.nuget.org/packages/StackExchange.Redis) | The Redis client. MassTransit.Redis uses it underneath, and the web app also uses it directly to keep a list of recent order IDs. |
| [`Microsoft.Azure.StackExchangeRedis`](https://www.nuget.org/packages/Microsoft.Azure.StackExchangeRedis) | Lets StackExchange.Redis sign in to Azure Cache for Redis with a Microsoft Entra token instead of an access key, and re-authenticates before the token expires. |
| [`Azure.Identity`](https://www.nuget.org/packages/Azure.Identity) | `ManagedIdentityCredential` gets tokens from the App Service managed identity endpoint, for Service Bus and (with Entra sign-in) Redis. |

> [!NOTE]
> This example pins **MassTransit 8.x**, which is Apache 2.0 licensed. MassTransit v9 onwards needs a commercial licence. Moving to v9 is a package bump plus a licence key, and the code here doesn't change.

### How the apps authenticate

When a web app has a managed identity, App Service sets `IDENTITY_ENDPOINT` and `IDENTITY_HEADER` in its container. `ManagedIdentityCredential` calls that endpoint for tokens, and `AZURE_CLIENT_ID` tells it which identity to use. See [`src/Program.cs`](https://github.com/tombuildsstuff/app-service-masstransit/blob/main/src/Program.cs).

* **Service Bus**: [`src/ServiceBus.cs`](https://github.com/tombuildsstuff/app-service-masstransit/blob/main/src/ServiceBus.cs) gives MassTransit the credential directly. `local_auth_enabled = false` on the namespace switches off SAS keys.
* **Redis** is set by the `redis_authentication` module variable:
  * `"entra"` (the default) makes [`src/Redis.cs`](https://github.com/tombuildsstuff/app-service-masstransit/blob/main/src/Redis.cs) call `ConfigureForAzureWithTokenCredentialAsync`, which signs in with the identity's object ID as the username and a token as the password. Access keys are switched off on the cache, and each identity gets a `Data Contributor` access policy assignment, aliased to its object ID.
  * `"access-key"` passes the cache's access key to each app as the `REDIS_KEY` app setting instead.

### Permissions

| Identity | Permission | Scope | Why |
| --- | --- | --- | --- |
| web | Azure Service Bus Data Owner | the namespace | MassTransit creates its topology and a temporary reply queue, which needs the Manage right |
| worker | Azure Service Bus Data Owner | the namespace | MassTransit creates the saga's and consumer's queues, topics and subscriptions |
| web | Redis `Data Contributor` (with `"entra"`) | the cache | the list of recent orders |
| worker | Redis `Data Contributor` (with `"entra"`) | the cache | the saga's state |

Data Owner is broader than the Sender/Receiver roles in the [Service Bus example](https://github.com/locallybuild/example-app-service-servicebus). That's the cost of letting MassTransit manage its own topology. When each app starts, MassTransit checks for and creates its entities through the Service Bus administration API, and that needs the Manage right.

## Requirements

* [Locally Build](https://locally.build).
* Either [HashiCorp Terraform](https://terraform.io) or [OpenTofu](https://opentofu.org).
* Either [Docker](https://www.docker.com) or [Podman](https://podman.io) (recommended).
* The Locally Plugin for `Microsoft.ServiceBus` installed (`locally plugin install --name Microsoft.ServiceBus`).
* The Locally Plugin for `Microsoft.Cache` installed (`locally plugin install --name Microsoft.Cache`).
* The Locally Plugin for `Microsoft.Web` installed (`locally plugin install --name Microsoft.Web`).
* The Locally Plugin for `Microsoft.ContainerRegistry` installed (`locally plugin install --name Microsoft.ContainerRegistry`).

You don't need the .NET SDK, or to build anything: the image is pulled from Docker Hub.

## Running the example

First, make sure your container runtime (Docker or Podman) is running, then start Locally:

```bash
locally build
```

With Locally running, open another terminal and initialise Terraform. This downloads the providers and sets up the module:

```bash
cd environments/locally
terraform init
```

> [!NOTE]
> You can use OpenTofu instead by running `tofu` wherever this says `terraform`.

Once Terraform is initialised, provision the example:

```bash
locally run terraform apply
```

During the apply, Terraform imports the image from Docker Hub into the Container Registry with `az acr import`, and App Service pulls it from there, the same as you'd host a private image on Azure. To run a different build, set the module's `container_image` variable.

After you approve the plan and the resources are deployed, both apps are running at the URLs in the outputs:

```
web_url    = "https://locally-example-masstransit-web.furnace.locally:5663"
worker_url = "https://locally-example-masstransit-worker.furnace.locally:5663"
```

[Open the web app](https://locally-example-masstransit-web.furnace.locally:5663) and place an order. It shows as `Submitted`, then moves to `Fulfilled` a couple of seconds later. Place an order for an item called `fail` and it ends up `Faulted`, after the consumer has been retried three times.

---

You can also look at each step from the CLI. MassTransit created these Service Bus entities when the apps started. To peek at the order that failed, which MassTransit moved to the error queue:

```bash
locally servicebus queue peek --namespace locally-example-masstransit-bus --name fulfil-order_error
```

Both apps send their logs to a Log Analytics Workspace. You can query them in [the Monitoring section of the Locally Dashboard](https://localhost:5678/monitoring/components) by running:

```
AppServiceConsoleLogs | order by TimeGenerated desc
```

## Running on Locally

The app uses MassTransit's standard Azure Service Bus topology unchanged, including its default `Namespace/Type` topic names (`Orders/OrderSubmitted`). Locally shows those names with `~` in place of `/` (`Orders~OrderSubmitted`), as Azure does in the portal and resource IDs.

One difference is worked around in the app, and is harmless on Azure: MassTransit creates entities through the Service Bus administration API over HTTPS. The SDK client takes only a hostname, so it always uses port 443, but Locally serves that API on the port in the namespace's endpoint (`:5662`). [`src/ServiceBus.cs`](https://github.com/tombuildsstuff/app-service-masstransit/blob/main/src/ServiceBus.cs) adds a pipeline policy to use that port when one is given.

## Notes

This example has no sign-in of its own: anyone who can reach the web app can place orders and see them. That keeps the example focused on the MassTransit, Service Bus and Redis wiring. A real app would sit behind authentication.

The saga instances are kept in Redis with no expiry, so they're still there after a restart. On a Basic cache, Redis itself isn't persisted, so recreating the cache loses them.

## Tearing it down

```bash
cd environments/locally
locally run terraform destroy
```
