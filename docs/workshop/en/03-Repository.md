# Forking and Cloning the Repository Locally

Before starting the hands-on, you will first **fork (copy) the repository on GitHub, which will be used as the teaching material, to your own account and clone that fork to your local environment**. This will allow you to prepare an environment where you can rewrite settings and code as your own repository without any problems.

## How to Fork a Repository on GitHub

1. **Access the Repository Page**: Open the [relevant repository page on GitHub](https://github.com/rioriost/postgres-agentic-shop) in your browser.

2. **Click the Fork Button**: Click the "Fork" button located near the top right of the repository. Select your own GitHub account as the destination for the fork, and you can leave the repository name as default (you can change it if necessary, but no changes are required for this hands-on).

3. **Confirm the Completion of the Fork**: After waiting a few seconds, the repository will be forked (copied) under your account. Please confirm that the URL on the browser is github.com/<your username>/postgres-agentic-shop.

> [!NOTE] Note
> Forking is not mandatory, but it is safe if you may make changes to the code during the exercise or if you want to proceed in your own environment. There is no operational problem even if you directly clone the official repository as it is. Please follow the instructions from the instructor.

## How to Clone the Repository Locally with git Command

1. **Obtain the Clone URL**: On the page of the forked repository, press the green "Code" button and copy the displayed clone URL. Either HTTPS or SSH is fine (if HTTPS, it will be in the format `https://github.com/<your username>/postgres-agentic-shop.git`).

2. **Open the Terminal**: Move to the working directory on your local PC (e.g., `C:\work` or `~/projects`), and open the terminal (PowerShell or Command Prompt for Windows, Terminal for macOS/Linux).

3. Execute Clone: Execute the following command to clone the repository.

```sh
git clone https://github.com/<your username>/postgres-agentic-shop.git
```

※Please replace the above URL part with the URL of your own fork that you copied.

4. **Move to the Directory**: Once the clone is complete, a new folder named `postgres-agentic-shop` will be created. Move into it.

```sh
cd postgres-agentic-shop
```

5. **Confirm the Contents of the Clone**: Confirm the contents with the `ls` command (or `dir` for Windows), and make sure you can see the directory structure of the source code, `README.md` file, and `azure.yaml` file. All subsequent work will be done within this repository directory.

This completes the acquisition of the repository. It would be good to open the code in an editor or read the `README` to get an overall picture. In particular, in this project, we will deploy using the **Azure Developer CLI (azd)**, so it will deepen your understanding to check what resources are defined in the `azure.yaml` and the templates in the `infra` directory.

[Back](02-Integration.md) | [Next](04-Provisioning.md)
